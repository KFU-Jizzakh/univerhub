module Dormitory
  class ViolationPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Violation — admin, dormitory.admin, and commandant have full CRUD access; commandant scope restricted to assigned buildings
    # SPECIFICATION: SPEC-DORM-10

    def index?
      admin_or_dormitory_admin_or_commandant?
    end

    def show?
      admin_or_dormitory_admin_or_commandant?
    end

    def create?
      admin_or_dormitory_admin_or_commandant?
    end

    def new?
      create?
    end

    def update?
      admin_or_dormitory_admin_or_commandant?
    end

    def edit?
      update?
    end

    def destroy?
      admin_or_dormitory_admin_or_commandant?
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def admin_or_dormitory_admin_or_commandant?
      admin_or_dormitory_admin? || user.has_role?("dormitory.commandant")
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.has_role?("admin") || user.has_role?("dormitory.admin")
          scope.kept.ordered
        elsif user.has_role?("dormitory.commandant")
          scope.kept
            .joins(:resident)
            .left_joins(resident: :current_room)
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
