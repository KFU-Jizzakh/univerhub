require "test_helper"

class DashboardPolicyTest < ActiveSupport::TestCase
  test "index? allowed for active users" do
    assert DashboardPolicy.new(users(:manager_user), :dashboard).index?
  end

  test "index? denied for deactivated users" do
    user = users(:manager_user)
    user.update!(deactivated_at: Time.current)
    assert_not DashboardPolicy.new(user, :dashboard).index?
  end
end
