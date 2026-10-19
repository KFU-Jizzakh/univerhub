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

  test "dual admin dashboard recent events follow the active role" do
    dual_admin = users(:dormitory_admin_user)
    dual_admin.add_role!("reporting.admin")

    resident = dormitory_residents(:resident_one_not_settled)
    OutboxEvent.create!(actor: users(:admin_user), action: "dormitory.resident.created", record: resident)
    report = reporting_reports(:new_report)
    OutboxEvent.create!(actor: users(:admin_user), action: "reporting.report.published", record: report)

    sign_in_as dual_admin
    get root_url
    assert_response :success
    assert_includes response.body, "добавил(а) проживающего"
    assert_not_includes response.body, "опубликовал(а) отчёт"

    patch active_role_path, params: { role_name: "reporting.admin" }
    get root_url
    assert_response :success
    assert_includes response.body, "опубликовал(а) отчёт"
    assert_not_includes response.body, "добавил(а) проживающего"
  end
end
