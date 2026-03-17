module Dormitory
  class DashboardPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Dormitory dashboard — accessible to admin, dormitory.admin, and commandant
    # SPECIFICATION: SPEC-DORM-07
    def index?
      admin_or_dormitory_admin? || commandant?
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def commandant?
      user.has_role?("dormitory.commandant")
    end
  end
end
