require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to login" do
    get root_url
    assert_redirected_to new_session_path
  end

  test "active user can access dashboard" do
    sign_in_as(users(:manager_user))
    get root_url
    assert_response :success
  end

  test "deactivated user is denied access" do
    user = users(:manager_user)
    user.update!(deactivated_at: Time.current)
    sign_in_as(user)

    get root_url
    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.deactivated"), flash[:alert]
  end

  test "reporting.admin dashboard shows all reports and events" do
    sign_in_as(users(:reporting_admin_user))
    get root_url
    assert_response :success
  end
end
