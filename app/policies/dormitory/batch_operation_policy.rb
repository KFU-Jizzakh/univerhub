module Dormitory
  class BatchOperationPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for BatchOperation — admin/dormitory.admin full access, commandant scoped to assigned buildings
    # SPECIFICATION: SPEC-DORM-05
    def index?
      admin_or_dormitory_admin_or_commandant?
    end

    def new?
      admin_or_dormitory_admin_or_commandant?
    end

    def create?
      admin_or_dormitory_admin_or_commandant?
    end

    def show?
      admin_or_dormitory_admin_or_commandant?
    end

    class Scope < Scope
      def resolve
        return scope.none unless user

        if user.has_role?("admin") || user.has_role?("dormitory.admin")
          scope.ordered
        elsif user.has_role?("dormitory.commandant")
          scope.joins(:building)
               .where(dormitory_buildings: { id: user.assigned_building_ids })
        else
          scope.none
        end
      end
    end

    private

    def admin_or_dormitory_admin_or_commandant?
      user.has_role?("admin") || user.has_role?("dormitory.admin") || user.has_role?("dormitory.commandant")
    end
  end
end
