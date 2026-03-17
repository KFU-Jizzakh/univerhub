module Dormitory
  class AcademicYear < ApplicationRecord
    # PURPOSE: Academic year entity with pending→active→closed lifecycle, unique active year constraint, and auto-assignment to accommodations
    # SPECIFICATION: SPEC-DORM-01
    include AASM
    include Discard::Model
    include Trackable

    has_many :accommodations, class_name: "Dormitory::Accommodation", dependent: :restrict_with_error

    validates :name, presence: true
    validates :start_date, presence: true
    validates :end_date, presence: true
    validate :start_date_before_end_date
    validate :name_unique_among_kept

    aasm column: :status do
      state :pending, initial: true
      state :active
      state :closed

      event :activate do
        transitions from: :pending, to: :active
      end

      event :close do
        transitions from: :active, to: :closed
      end
    end

    scope :active, -> { where(status: :active) }
    scope :ordered, -> { order(start_date: :desc) }

    def do_create!
      track_event("dormitory.academic_year.created") { save! }
    end

    def do_activate!
      raise ActiveRecord::RecordInvalid, self unless pending?

      if Dormitory::AcademicYear.active.exists?
        errors.add(:base, :already_active)
        raise ActiveRecord::RecordInvalid, self
      end

      track_event("dormitory.academic_year.activated") { activate! }
    end

    def do_update!(attrs)
      raise ActiveRecord::RecordInvalid, self if closed?

      track_event("dormitory.academic_year.updated") { update!(attrs) }
    end

    def do_discard!
      unless pending?
        errors.add(:status, :cannot_delete_not_pending)
        raise ActiveRecord::RecordInvalid, self
      end

      track_event("dormitory.academic_year.discarded") { discard! }
    end

    def do_close!
      raise ActiveRecord::RecordInvalid, self unless active?

      if accommodations.active.exists?
        errors.add(:base, :has_active_accommodations)
        raise ActiveRecord::RecordInvalid, self
      end

      track_event("dormitory.academic_year.closed") do
        update!(closed_at: Time.current)
        close!
      end
    end

    private

    def start_date_before_end_date
      return unless start_date && end_date
      return unless start_date >= end_date

      errors.add(:end_date, :must_be_after_start_date)
    end

    def name_unique_among_kept
      return unless name

      scope = self.class.kept.where(name: name)
      scope = scope.where.not(id: id) if persisted?

      errors.add(:name, :taken) if scope.exists?
    end
  end
end
