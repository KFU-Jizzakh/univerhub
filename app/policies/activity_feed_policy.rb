class ActivityFeedPolicy < ApplicationPolicy
  def index?
    user.has_role?("supervisor") || user.has_role?("admin") || user.has_role?("reporting.admin") || user.has_role?("dormitory.admin")
  end
end
