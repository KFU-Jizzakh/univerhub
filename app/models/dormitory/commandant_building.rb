module Dormitory
  class CommandantBuilding < ApplicationRecord
    # PURPOSE: Links commandant users to buildings they manage, with soft-deactivation support
    # SPECIFICATION: SPEC-DORM-08
    include Trackable

    belongs_to :user
    belongs_to :building, class_name: "Dormitory::Building"

    validates :user, :building, presence: true
    validates :building_id, uniqueness: {
      scope: :user_id,
      conditions: -> { where(deactivated_at: nil) },
      message: :already_assigned
    }

    scope :active, -> { where(deactivated_at: nil) }
    scope :deactivated, -> { where.not(deactivated_at: nil) }

    def do_create!
      track_event("dormitory.commandant_building.created") { save! }
    end

    def do_update!(attrs)
      track_event("dormitory.commandant_building.updated") { update!(attrs) }
    end

    def do_deactivate!
      track_event("dormitory.commandant_building.deactivated") { deactivate! }
    end

    def do_destroy!
      track_event("dormitory.commandant_building.destroyed") { destroy! }
    end

    def active?
      deactivated_at.nil?
    end

    private

    def deactivate!
      update!(deactivated_at: Time.current)
    end
  end
end
