require "test_helper"

class ActivityFeedPolicyTest < ActiveSupport::TestCase
  test "index? allowed for supervisor, admin, reporting.admin, and dormitory.admin" do
    assert ActivityFeedPolicy.new(users(:admin_user), :activity_feed).index?
    assert ActivityFeedPolicy.new(users(:supervisor_user), :activity_feed).index?
    assert ActivityFeedPolicy.new(users(:reporting_admin_user), :activity_feed).index?
    assert ActivityFeedPolicy.new(users(:dormitory_admin_user), :activity_feed).index?
  end

  test "index? denied for other roles" do
    [ :manager_user, :reporter_user, :reviewer_user, :visitor_user, :dormitory_commandant_user ].each do |u|
      assert_not ActivityFeedPolicy.new(users(u), :activity_feed).index?
    end
  end
end
