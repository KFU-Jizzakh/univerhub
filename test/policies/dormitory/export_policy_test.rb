require "test_helper"

class Dormitory::ExportPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
  end

  test "admin can access export index" do
    policy = Dormitory::ExportPolicy.new(@admin, :dormitory_export)
    assert policy.index?
  end

  test "commandant can access export index" do
    policy = Dormitory::ExportPolicy.new(@commandant, :dormitory_export)
    assert policy.index?
  end

  test "manager cannot access export index" do
    policy = Dormitory::ExportPolicy.new(@manager, :dormitory_export)
    assert_not policy.index?
  end
end
