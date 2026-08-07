module Dormitory
  class AcademicYearPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for AcademicYear — admin/dormitory.admin manage, commandant and registrar view only
    # SPECIFICATION: SPEC-DORM-01
    def index?
      admin_or_dormitory_admin_or_commandant? || registrar?
    end

    def show?
      admin_or_dormitory_admin_or_commandant? || registrar?
    end

    def new?
      admin_or_dormitory_admin?
    end

    def create?
      admin_or_dormitory_admin?
    end

    def edit?
      admin_or_dormitory_admin?
    end

    def update?
      admin_or_dormitory_admin?
    end

    def destroy?
      admin_or_dormitory_admin?
    end

    class Scope < Scope
      def resolve
        return scope.none unless user

        if user.has_role?("admin") || user.has_role?("dormitory.admin") ||
           user.has_role?("dormitory.commandant") || user.has_role?("dormitory.registrar")
          scope.kept.ordered
        else
          scope.none
        end
      end
    end

    private

    def admin_or_dormitory_admin_or_commandant?
      user.has_role?("admin") || user.has_role?("dormitory.admin") || user.has_role?("dormitory.commandant")
    end

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def registrar?
      user.has_role?("dormitory.registrar")
    end
  end
end
