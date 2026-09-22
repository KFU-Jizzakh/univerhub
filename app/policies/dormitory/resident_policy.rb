module Dormitory
  class ResidentPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Resident — admin/dormitory.admin full access, commandant scoped to assigned buildings, registrar global create/edit without destroy
    # SPECIFICATION: SPEC-DORM-03, SPEC-DORM-12
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

    # PURPOSE: Whether the user may register a resident with a place (manual room and bed selection during registration)
    # SPECIFICATION: SPEC-DORM-12
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

    # PURPOSE: Whether the residents index payment aggregates must be scoped to the commandant's assigned buildings — only for a user without higher-privilege roles
    # SPECIFICATION: SPEC-DORM-09
    def building_scoped_aggregates?
      self.class.building_scoped_user?(user)
    end

    # PURPOSE: Whether the user holds a role above commandant (admin, dormitory.admin, or registrar)
    # SPECIFICATION: SPEC-DORM-09
    def self.higher_privilege?(user)
      user.has_role?("admin") || user.has_role?("dormitory.admin") || user.has_role?("dormitory.registrar")
    end

    # PURPOSE: Whether the user is a pure commandant (no higher-privilege roles), whose dormitory views are scoped to assigned buildings
    # SPECIFICATION: SPEC-DORM-09
    def self.building_scoped_user?(user)
      user.has_role?("dormitory.commandant") && !higher_privilege?(user)
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
