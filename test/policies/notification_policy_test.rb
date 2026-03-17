require "test_helper"

class NotificationPolicyTest < ActiveSupport::TestCase
  setup do
    @recipient = users(:reporter_user)
    @other     = users(:reviewer_user)
    @notif     = Notification.create!(recipient: @recipient, action: "reporting.report.assigned", notifiable: reporting_reports(:new_report))
  end

  test "index? and mark_all_as_read? are true" do
    assert NotificationPolicy.new(@recipient, @notif).index?
    assert NotificationPolicy.new(@recipient, @notif).mark_all_as_read?
  end

  test "mark_as_read? allowed for recipient only" do
    assert NotificationPolicy.new(@recipient, @notif).mark_as_read?
    assert_not NotificationPolicy.new(@other, @notif).mark_as_read?
  end
end
