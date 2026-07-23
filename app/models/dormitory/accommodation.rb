module Dormitory
  class Accommodation < ApplicationRecord
    # PURPOSE: Core settlement operations: settling residents into rooms, transferring between rooms, and evicting with document management, payment tracking, and date tracking
    # SPECIFICATION: SPEC-DORM-04, SPEC-DORM-09
    include AASM
    include Discard::Model
    include Trackable

    belongs_to :resident, class_name: "Dormitory::Resident"
    belongs_to :room, class_name: "Dormitory::Room"
    belongs_to :academic_year, class_name: "Dormitory::AcademicYear"
    belongs_to :renewal_source, class_name: "Dormitory::Accommodation", optional: true

    has_one_attached :application_file
    has_one_attached :contract_file
    has_many :receipts, -> { kept }, dependent: :destroy, class_name: "Dormitory::Receipt", autosave: true

    EVICTION_REASONS = %w[transfer graduation expulsion voluntary violation repair other].freeze
    ACCEPTED_FILE_TYPES = %w[application/pdf image/jpeg image/png].freeze
    MAX_FILE_SIZE = 10.megabytes

    validates :resident, :room, :application_number, :contract_number, :start_date, :planned_end_date, presence: true
    validates :comment, length: { maximum: 2000 }
    validates :eviction_reason, inclusion: { in: EVICTION_REASONS }, allow_nil: true
    validates :required_amount, numericality: { greater_than_or_equal_to: 0 }
    validate :application_file_format_and_size
    validate :contract_file_format_and_size
    validate :comment_required_for_other_reason, if: -> { eviction_reason == "other" }
    validate :planned_end_date_after_start_date
    validate :renewal_source_must_be_completed
    validates :actual_end_date, presence: true, if: -> { completed? || cancelled? }
    validate :actual_end_date_not_before_start_date
    validate :actual_end_date_not_in_future
    validate :no_actual_end_date_when_active

    before_validation :set_academic_year, on: :create

    aasm column: :status, whiny_transitions: true do
      state :active, initial: true
      state :completed
      state :cancelled

      event :complete do
        transitions from: :active, to: :completed
      end

      event :cancel do
        transitions from: :active, to: :cancelled
      end
    end

    scope :ordered, -> { order(created_at: :desc) }
    scope :overdue, -> { active.where("planned_end_date < ?", Date.current) }

    def planned_duration_days
      return nil unless start_date && planned_end_date

      (planned_end_date - start_date).to_i
    end

    def actual_duration_days
      return nil unless start_date && actual_end_date

      (actual_end_date - start_date).to_i
    end

    def overdue?
      active? && planned_end_date && planned_end_date < Date.current
    end

    def total_paid
      receipts.sum(:amount)
    end

    def balance
      total_paid - required_amount
    end

    def payment_overdue?
      active? && balance.negative?
    end

    def do_update!(attrs)
      track_event("dormitory.accommodation.updated") { update!(attrs) }
    end

    def do_settle!(force: false)
      raise ActiveRecord::RecordInvalid.new(self) unless resident&.present? && room&.present?

      track_event("dormitory.accommodation.created",
                  { resident_id: resident.id, room_id: room.id, room_number: room.number, force: force }) do
        room.with_lock do
          resident.lock!
          validate_settle_preconditions!(force)
          validate_room_capacity!(force)
          room.skip_capacity_validation = true if force
          save!
          resident.update!(status: :settled, current_room: room)
          room.increment!(:current_occupancy)
          trigger_room_transition!(force)
        end
      end
      self
    end

    def do_transfer!(new_acc, eviction_reason: "transfer")
      validate_transfer_preconditions!(new_acc)

      track_event("dormitory.accommodation.transferred",
                  { resident_id: resident.id, from_room_id: room_id,
                    to_room_id: new_acc.room_id, eviction_reason: eviction_reason }) do
        new_room = Dormitory::Room.find(new_acc.room_id)
        old_room = Dormitory::Room.find(room_id)

        [ old_room.id, new_room.id ].sort.each { |rid| Dormitory::Room.where(id: rid).lock.pluck(:id) }
        old_room.reload
        new_room.reload

        validate_transfer_room!(new_room)
        validate_transfer_files!(new_acc)

        self.eviction_reason = eviction_reason
        self.actual_end_date = Date.current
        complete!

        old_room.decrement!(:current_occupancy)
        recalculate_room_status!(old_room, eviction_reason)

        new_acc.resident = resident
        new_acc.save!

        OutboxEvent.create!(
          actor: Current.user,
          action: "dormitory.accommodation.created",
          record: new_acc,
          payload: { resident_id: resident.id, room_id: new_room.id, room_number: new_room.number, via: :transfer }
        )

        new_room.increment!(:current_occupancy)
        trigger_new_room_transition!(new_room)

        resident.update!(status: :settled, current_room: new_room)

        new_acc
      end
    end

    def do_evict!(eviction_reason:, comment: nil)
      validate_eviction_preconditions!
      validate_eviction_reason!(eviction_reason, comment)

      track_event("dormitory.accommodation.evicted",
                  { resident_id: resident.id, room_id: room_id, room_number: room.number,
                    eviction_reason: eviction_reason }) do
        room.with_lock do
          self.eviction_reason = eviction_reason
          self.actual_end_date = Date.current
          self.comment = comment
          complete!

          room.decrement!(:current_occupancy)
          resident.update!(status: :evicted, current_room_id: nil)
          recalculate_room_status!(room, eviction_reason)
        end
      end
      self
    end

    private

    def validate_eviction_preconditions!
      unless active?
        errors.add(:status, :not_active)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      unless resident&.settled? || resident&.temporarily_absent?
        errors.add(:resident, :not_settled)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def validate_eviction_reason!(eviction_reason, comment)
      unless EVICTION_REASONS.include?(eviction_reason)
        errors.add(:eviction_reason, :invalid)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      if other_reason_requires_comment?(eviction_reason, comment)
        errors.add(:comment, :required_for_other)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def comment_required_for_other_reason
      if other_reason_requires_comment?(eviction_reason, comment)
        errors.add(:comment, :required_for_other)
      end
    end

    def other_reason_requires_comment?(reason, comment_text)
      reason == "other" && comment_text.blank?
    end

    def validate_settle_preconditions!(force)
      if resident.status != "not_settled"
        errors.add(:resident, :already_settled)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      unless gender_compatible?
        errors.add(:room, :gender_conflict)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      unless application_file.attached? && contract_file.attached?
        errors.add(:base, :files_required)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def validate_room_capacity!(force)
      if !force && room.current_occupancy >= room.capacity
        errors.add(:room, :full)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def gender_compatible?
      room.gender_restriction.nil? || room.gender_restriction.to_s == resident.gender
    end

    def gender_compatible_with?(other_room)
      other_room.gender_restriction.nil? || other_room.gender_restriction.to_s == resident.gender
    end

    def trigger_room_transition!(force)
      case room.aasm.current_state
      when :free
        room.occupy!
        room.track_status_change!(:occupy)
      when :partially_occupied
        room.occupy_more!
        room.track_status_change!(:occupy_more)
      when :fully_occupied
        raise ActiveRecord::RecordInvalid.new(self) unless force
        room.force_occupy!
        room.track_status_change!(:force_occupy)
      else
        errors.add(:room, :invalid_state)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def validate_transfer_preconditions!(new_acc)
      unless active?
        errors.add(:status, :not_active)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      unless resident&.settled? || resident&.temporarily_absent?
        errors.add(:resident, :not_settled)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      if planned_end_date && new_acc.planned_end_date && planned_end_date > new_acc.planned_end_date
        errors.add(:planned_end_date, :shorter_transfer)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def validate_transfer_room!(new_room)
      if new_room.id == room_id
        errors.add(:room, :same_room)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      if new_room.current_occupancy >= new_room.capacity
        errors.add(:room, :full)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      unless gender_compatible_with?(new_room)
        errors.add(:room, :gender_conflict)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def validate_transfer_files!(new_acc)
      unless new_acc.application_file.attached? && new_acc.contract_file.attached?
        new_acc.errors.add(:base, :files_required)
        raise ActiveRecord::RecordInvalid.new(new_acc)
      end
    end

    def recalculate_room_status!(old_room, eviction_reason)
      case old_room.aasm.current_state
      when :partially_occupied
        if old_room.current_occupancy.zero?
          old_room.evict_all!
          old_room.track_status_change!(:evict_all)
        end
      when :fully_occupied
        if old_room.current_occupancy.zero?
          old_room.evict_all!
          old_room.track_status_change!(:evict_all)
        elsif old_room.current_occupancy < old_room.capacity
          old_room.evict_partial!
          old_room.track_status_change!(:evict_partial)
        end
      when :overcrowded
        if old_room.current_occupancy.zero?
          old_room.evict_all!
          old_room.track_status_change!(:evict_all)
        elsif old_room.current_occupancy == old_room.capacity
          old_room.normalize!
          old_room.track_status_change!(:normalize)
        elsif old_room.current_occupancy > 0 && old_room.current_occupancy < old_room.capacity
          old_room.evict_partial!
          old_room.track_status_change!(:evict_partial)
        end
      else
        # :free — no occupancy recalculation needed
      end
    end

    def trigger_new_room_transition!(new_room)
      case new_room.aasm.current_state
      when :free
        new_room.occupy!
        new_room.track_status_change!(:occupy)
      when :partially_occupied
        new_room.occupy_more!
        new_room.track_status_change!(:occupy_more)
      else
        errors.add(:room, :invalid_state)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def validate_file(attachment, attribute_name)
      return unless attachment.attached?

      unless attachment.content_type.in?(ACCEPTED_FILE_TYPES)
        errors.add(attribute_name, :invalid_file_format)
      end

      if attachment.byte_size > MAX_FILE_SIZE
        errors.add(attribute_name, :file_too_large)
      end
    end

    def application_file_format_and_size
      validate_file(application_file, :application_file)
    end

    def contract_file_format_and_size
      validate_file(contract_file, :contract_file)
    end

    def planned_end_date_after_start_date
      return unless planned_end_date && start_date
      return unless planned_end_date < start_date

      errors.add(:planned_end_date, :must_be_after_start_date)
    end

    def set_academic_year
      return if academic_year_id.present?

      active_year = Dormitory::AcademicYear.active.first
      if active_year
        self.academic_year = active_year
      else
        errors.add(:base, :no_active_academic_year)
      end
    end

    def renewal_source_must_be_completed
      return unless renewal_source_id.present?

      source = Dormitory::Accommodation.find_by(id: renewal_source_id)
      return unless source && !source.completed?

      errors.add(:renewal_source_id, :must_be_completed)
    end

    def actual_end_date_not_before_start_date
      return unless actual_end_date && start_date
      return unless actual_end_date < start_date

      errors.add(:actual_end_date, :before_start_date)
    end

    def actual_end_date_not_in_future
      return unless actual_end_date
      return unless actual_end_date > Date.current

      errors.add(:actual_end_date, :future_date)
    end

    def no_actual_end_date_when_active
      return unless active? && actual_end_date.present?

      errors.add(:actual_end_date, :present_when_active)
    end
  end
end
