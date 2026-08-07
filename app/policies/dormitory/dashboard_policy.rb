module Dormitory
  class DashboardPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for Dormitory dashboard — accessible to admin, dormitory.admin, commandant, and registrar (global stats)
    # SPECIFICATION: SPEC-DORM-07
    def index?
      admin_or_dormitory_admin? || commandant? || registrar?
    end

    private

    def admin_or_dormitory_admin?
      user.has_role?("admin") || user.has_role?("dormitory.admin")
    end

    def commandant?
      user.has_role?("dormitory.commandant")
    end

    def registrar?
      user.has_role?("dormitory.registrar")
    end
  end
end
