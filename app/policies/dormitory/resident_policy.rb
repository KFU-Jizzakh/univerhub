module Dormitory
  class ResidentPolicy < ApplicationPolicy
    def index?
      self.class.higher_privilege?(user) || commandant?
    end

    def show?
      self.class.higher_privilege?(user) || commandant_with_access?
    end

    def create?
      admin_or_dormitory_admin? || commandant_with_building_access? || registrar?
    end

    def new?
      create?
    end

    def create_with_placement?
      admin_or_dormitory_admin? || commandant_with_building_access? || registrar?
    end

    def update?
      return false if record.discarded?

      admin_or_dormitory_admin? || commandant_with_access? || registrar?
    end

    def edit?
      update?
    end

    def destroy?
      admin_or_dormitory_admin?
    end

    def check_ticket?
      self.class.higher_privilege?(user) || commandant?
    end

    def building_scoped_aggregates?
      self.class.building_scoped_user?(user)
    end

    def self.higher_privilege?(user)
      user.has_role?("admin") || user.has_role?("dormitory.admin") || user.has_role?("dormitory.registrar")
    end

    def self.building_scoped_user?(user)
      user.has_role?("dormitory.commandant")
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def registrar?
      user.has_role?("dormitory.registrar")
    end

    def commandant?
      user.has_role?("dormitory.commandant")
    end

    def commandant_with_access?
      return false unless commandant?
      return true if record.current_room_id.nil?
      record.current_room&.building_id&.in?(user.assigned_building_ids)
    end

    def commandant_with_building_access?
      commandant? && user.assigned_building_ids.any?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if Dormitory::ResidentPolicy.higher_privilege?(user)
          scope.kept.includes(:current_room).ordered
        elsif Dormitory::ResidentPolicy.building_scoped_user?(user)
          scope.kept
            .includes(:current_room)
            .left_joins(:current_room)
            .where(
              "dormitory_residents.current_room_id IS NULL OR dormitory_rooms.building_id IN (?)",
              user.assigned_building_ids,
            )
            .ordered
        else
          scope.none
        end
      end
    end
  end
end
