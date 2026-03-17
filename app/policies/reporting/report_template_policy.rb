module Reporting
  class ReportTemplatePolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for ReportTemplate — manager/admin manage, published visible to all
    # SPECIFICATION: SPEC-REPT-02
    def index?
      true
    end

    def show?
      user.has_role?("admin") || user.has_role?("reporting.admin") || user.has_role?("reporting.manager") || record.published?
    end

    def create?
      user.has_role?("admin") || user.has_role?("reporting.manager") || user.has_role?("reporting.admin")
    end

    def update?
      user.has_role?("admin") || (owner_manager? && record.draft?) || user.has_role?("reporting.admin")
    end

    def destroy?
      user.has_role?("admin") || (owner_manager? && record.draft?) || user.has_role?("reporting.admin")
    end

    def publish?
      user.has_role?("admin") || (owner_manager? && record.draft?) || user.has_role?("reporting.admin")
    end

    def archive?
      user.has_role?("admin") || (owner_manager? && record.published?) || user.has_role?("reporting.admin")
    end

    private

    def owner_manager?
      user.has_role?("admin") ||
        (user.has_role?("reporting.manager") && record.creator_id == user.id) ||
        user.has_role?("reporting.admin")
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.has_role?("admin") || user.has_role?("reporting.manager") || user.has_role?("reporting.admin")
          scope.all
        else
          scope.available
        end
      end
    end
  end
end
