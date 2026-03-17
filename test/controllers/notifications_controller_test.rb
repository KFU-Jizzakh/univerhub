require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  test "index shows user's notifications" do
    sign_in_as(users(:manager_user))
    get notifications_path
    assert_response :success
    assert_select ".notification-item", count: 2
  end

  test "mark_as_read marks notification as read" do
    sign_in_as(users(:manager_user))
    notification = notifications(:unread_notification)

    assert_not notification.read?

    patch mark_as_read_notification_path(notification)

    assert_redirected_to notifications_path
    notification.reload
    assert notification.read?
  end

  test "mark_all_as_read marks all notifications as read" do
    sign_in_as(users(:manager_user))

    patch mark_all_as_read_notifications_path

    assert_redirected_to notifications_path
    assert_equal I18n.t("notifications.all_read"), flash[:notice]
    assert_equal 0, users(:manager_user).notifications.unread.count
  end
end
