module Dormitory
  class BuildingPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Building — admin/dormitory.admin manage, commandant views assigned only
    # SPECIFICATION: SPEC-DORM-02
    def index?
      admin_or_dormitory_admin? || commandant?
    end

    def show?
      admin_or_dormitory_admin? || commandant_with_access?
    end

    def create?
      admin_or_dormitory_admin?
    end

    def new?
      create?
    end

    def update?
      admin_or_dormitory_admin?
    end

    def edit?
      update?
    end

    def destroy?
      admin_or_dormitory_admin?
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def commandant?
      user.has_role?("dormitory.commandant")
    end

    def commandant_with_access?
      commandant? && user.assigned_building_ids.include?(record.id)
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.has_role?("admin") || user.has_role?("dormitory.admin")
          scope.kept.ordered
        elsif user.has_role?("dormitory.commandant")
          scope.kept.ordered.where(id: user.assigned_building_ids)
        else
          scope.none
        end
      end
    end
  end
end
