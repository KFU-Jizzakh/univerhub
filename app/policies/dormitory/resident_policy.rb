module Dormitory
  class ResidentPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Resident — admin/dormitory.admin full access, commandant scoped to assigned buildings, registrar global create/edit without destroy
    # SPECIFICATION: SPEC-DORM-03, SPEC-DORM-12
    def index?
      admin_or_dormitory_admin_or_commandant? || registrar?
    end

    def show?
      admin_or_dormitory_admin? || commandant_with_access? || registrar?
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
      admin_or_dormitory_admin? || commandant_with_access? || registrar?
    end

    def edit?
      update?
    end

    def destroy?
      admin_or_dormitory_admin?
    end

    def check_ticket?
      admin_or_dormitory_admin_or_commandant? || registrar?
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def admin_or_dormitory_admin_or_commandant?
      admin_or_dormitory_admin? || user.has_role?("dormitory.commandant")
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
        if user.has_role?("admin") || user.has_role?("dormitory.admin")
          scope.kept.includes(:current_room).ordered
        elsif user.has_role?("dormitory.registrar")
          scope.kept.includes(:current_room).ordered
        elsif user.has_role?("dormitory.commandant")
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
