require "test_helper"

class ActiveRolePolicyTest < ActiveSupport::TestCase
  test "update? true for an assigned role" do
    user = users(:admin_user)

    assert ActiveRolePolicy.new(user, "admin").update?
  end

  test "update? false for a role the user does not have" do
    user = users(:dormitory_commandant_user)

    assert_not ActiveRolePolicy.new(user, "admin").update?
  end
end
