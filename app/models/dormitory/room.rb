module Dormitory
  class Room < ApplicationRecord
    # PURPOSE: Dormitory room with AASM occupancy state machine, gender restriction, and capacity management
    # SPECIFICATION: SPEC-DORM-02
    include AASM
    include Discard::Model
    include Trackable

    belongs_to :building, class_name: "Dormitory::Building"

    has_many :accommodations, class_name: "Dormitory::Accommodation", dependent: :restrict_with_error
    has_many :current_residents, -> { where(status: [ :settled, :temporarily_absent ]) },
             class_name: "Dormitory::Resident", foreign_key: :current_room_id

    enum :gender_restriction, { male: 0, female: 1 }

    validates :number, presence: true
    validates :building, presence: true
    validates :floor, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :capacity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :current_occupancy, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :floor_within_building_range
    validate :capacity_not_less_than_occupancy, on: :update, unless: :skip_capacity_validation?

    attr_accessor :skip_capacity_validation
    validate :number_unique_in_building

    scope :ordered, -> { order(:floor, :number) }

    def self.available_for(gender, building_id: nil)
      scope = kept.where(status: [ :free, :partially_occupied ])
      scope = scope.where(building_id: building_id) if building_id
      scope = scope.where(
        "gender_restriction IS NULL OR gender_restriction = ?", Dormitory::Room.gender_restrictions[gender]
      ) if gender
      scope.selectable
    end

    def self.selectable
      kept.ordered
    end

    def available_slots
      capacity - current_occupancy
    end

    aasm column: :status, whiny_transitions: true, whiny_persistence: true do
      state :free, initial: true
      state :partially_occupied
      state :fully_occupied
      state :overcrowded

      event :occupy do
        transitions from: :free, to: :partially_occupied, guard: :partial_occupation?
        transitions from: :free, to: :fully_occupied, guard: :full_occupation?
      end

      event :occupy_more do
        transitions from: :partially_occupied, to: :fully_occupied, guard: :full_occupation?
        transitions from: :partially_occupied, to: :partially_occupied, guard: :partial_occupation?
      end

      event :force_occupy do
        transitions from: :fully_occupied, to: :overcrowded, before: :set_skip_capacity_validation
      end

      event :evict_partial do
        transitions from: :fully_occupied, to: :partially_occupied, guard: :partial_occupation?
        transitions from: :overcrowded, to: :fully_occupied, guard: :full_occupation?
        transitions from: :overcrowded, to: :partially_occupied, guard: :partial_occupation?
      end

      event :evict_all do
        transitions from: [ :partially_occupied, :fully_occupied, :overcrowded ], to: :free
      end

      event :normalize do
        transitions from: :overcrowded, to: :fully_occupied, guard: :full_occupation?
      end
    end

    def do_create!
      track_event("dormitory.room.created") { save! }
    end

    def track_status_change!(event)
      return unless previous_changes.key?("status")

      OutboxEvent.create!(
        actor: Current.user,
        action: "dormitory.room.#{event}",
        record: self,
        payload: {
          from: previous_changes["status"].first,
          to: previous_changes["status"].last,
          building_id: building_id,
          number: number
        }
      )
    end

    def do_update!(attrs)
      track_event("dormitory.room.updated") { update!(attrs) }
    end

    def do_discard!
      unless free?
        errors.add(:status, :cannot_delete_not_free)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      unless empty?
        errors.add(:base, :cannot_delete_occupied)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      track_event("dormitory.room.discarded") { discard! }
    end

    def empty?
      current_occupancy.zero?
    end

    def suggested_number
      return nil unless building && floor

      max_number = building.rooms.kept
        .where(floor: floor)
        .maximum("CAST(number AS INTEGER)") || 0

      floor_base = floor * 100
      [ floor_base + 1, max_number + 1 ].max.to_s
    end

    private

    def partial_occupation?
      current_occupancy > 0 && current_occupancy < capacity
    end

    def full_occupation?
      current_occupancy == capacity
    end

    def floor_within_building_range
      return unless building && floor

      if floor > building.floors_count
        errors.add(:floor, :greater_than_allowed, count: building.floors_count)
      end
    end

    def capacity_not_less_than_occupancy
      return unless capacity && current_occupancy
      return if overcrowded?

      if current_occupancy > capacity
        errors.add(:capacity, :less_than_occupancy, count: current_occupancy)
      end
    end

    def skip_capacity_validation?
      ActiveRecord::Type::Boolean.new.cast(skip_capacity_validation)
    end

    def set_skip_capacity_validation
      self.skip_capacity_validation = true
    end

    def number_unique_in_building
      return unless number && building_id

      scope = self.class.kept.where(building_id: building_id, number: number)
      scope = scope.where.not(id: id) if persisted?

      if scope.exists?
        errors.add(:number, :taken_in_building)
      end
    end
  end
end
