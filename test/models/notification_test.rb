require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @reporter = users(:reporter_user)
    @notification = Notification.create!(
      recipient: @reporter,
      notifiable: reporting_reports(:new_report),
      action: "reporting.report.assigned"
    )
  end

  test "read? returns false when not read" do
    assert_not @notification.read?
  end

  test "read? returns true after mark_as_read!" do
    @notification.mark_as_read!
    assert @notification.read?
  end

  test "mark_as_read! persists read_at" do
    assert_nil @notification.read_at
    @notification.mark_as_read!
    assert_not_nil @notification.reload.read_at
  end

  test "unread scope excludes read notifications" do
    read = Notification.create!(
      recipient: @reporter,
      notifiable: reporting_reports(:new_report),
      action: "reporting.report.accepted",
      read_at: Time.current
    )
    assert_includes Notification.unread, @notification
    assert_not_includes Notification.unread, read
  end

  test "recent scope orders by created_at desc" do
    newer = Notification.create!(
      recipient: @reporter,
      notifiable: reporting_reports(:in_review_report),
      action: "reporting.report.submitted"
    )
    assert_equal newer, @reporter.notifications.recent.first
  end
end
