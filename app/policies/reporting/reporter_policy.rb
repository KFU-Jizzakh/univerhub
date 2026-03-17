module Reporting
  class ReporterPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for viewing reporter profiles — visitor, admin, supervisor, reporting.admin
    # SPECIFICATION: SPEC-REPT-01
    def index?
      user.has_role?("reporting.visitor") || user.has_role?("admin") || user.has_role?("supervisor") || user.has_role?("reporting.admin")
    end

    def show?
      index?
    end
  end
end
