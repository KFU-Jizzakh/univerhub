class ActiveRolePolicy < ApplicationPolicy
  # record is the requested role name
  def update?
    user.assigned_role?(record)
  end
end
