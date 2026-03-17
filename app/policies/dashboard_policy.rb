class DashboardPolicy < ApplicationPolicy
  def index?
    user&.active?
  end
end
