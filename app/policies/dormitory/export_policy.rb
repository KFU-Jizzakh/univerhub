module Dormitory
  class ExportPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for CSV exports — accessible to admin, dormitory.admin, commandant, and registrar (read-only)
    # SPECIFICATION: SPEC-DORM-06
    def index?
      admin_or_dormitory_admin_or_commandant? || registrar?
    end

    private

    def admin_or_dormitory_admin_or_commandant?
      user.has_role?("admin") || user.has_role?("dormitory.admin") || user.has_role?("dormitory.commandant")
    end

    def registrar?
      user.has_role?("dormitory.registrar")
    end
  end
end
