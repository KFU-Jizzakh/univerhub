class ActivityFeedPolicy < ApplicationPolicy
  # PURPOSE: Authorization rules for ActivityFeed — accessible to supervisor, admin, and scoped admins
  # SPECIFICATION: SPEC-CORE-04
  def index?
    user.has_role?("supervisor") || user.has_role?("admin") || user.has_role?("reporting.admin") || user.has_role?("dormitory.admin")
  end
end
