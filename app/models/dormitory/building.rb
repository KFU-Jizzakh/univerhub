module Dormitory
  class Building < ApplicationRecord
    # PURPOSE: Dormitory building with rooms, address, floor count, and discard protection
    # SPECIFICATION: SPEC-DORM-02
    include Discard::Model
    include Trackable

    validates :name, presence: true, uniqueness: true
    validates :address, presence: true
    validates :floors_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

    has_many :rooms, class_name: "Dormitory::Room", dependent: :restrict_with_error
    has_many :current_residents, through: :rooms

    scope :ordered, -> { order(:name) }

    def do_create!
      track_event("dormitory.building.created") { save! }
    end

    def do_update!(attrs)
      track_event("dormitory.building.updated") { update!(attrs) }
    end

    def do_discard!
      if rooms.kept.exists?
        errors.add(:base, :cannot_delete_with_rooms)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      track_event("dormitory.building.discarded") { discard! }
    end
  end
end
