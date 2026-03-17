module Reporting
  class ReportCommentPolicy < ApplicationPolicy
    # PURPOSE: Authorization rules for ReportComment — participants can create, author/admin can delete
    # SPECIFICATION: SPEC-REPT-01
    def show?
      Reporting::ReportPolicy.new(user, record.report).access_comments?
    end

    def create?
      Reporting::ReportPolicy.new(user, record.report).access_comments?
    end

    def destroy?
      record.user_id == user.id || user.has_role?("admin") || user.has_role?("reporting.admin")
    end
  end
end
