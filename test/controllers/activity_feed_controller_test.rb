require "test_helper"

class ActivityFeedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @reporting_admin = users(:reporting_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "index requires auth" do
    get activity_feed_index_path
    assert_redirected_to new_session_path
  end

  test "index denied for manager" do
    sign_in_as @manager
    get activity_feed_index_path
    assert_redirected_to root_path
  end

  test "index denied for commandant" do
    sign_in_as @commandant
    get activity_feed_index_path
    assert_redirected_to root_path
  end

  test "index renders for admin" do
    sign_in_as @admin
    get activity_feed_index_path
    assert_response :success
  end

  test "index renders for reporting.admin" do
    sign_in_as @reporting_admin
    get activity_feed_index_path
    assert_response :success
  end

  test "index renders for dormitory.admin" do
    sign_in_as @dormitory_admin
    get activity_feed_index_path
    assert_response :success
  end

  test "dormitory.admin sees only dormitory events" do
    resident = Dormitory::Resident.create!(
      last_name: "Test", first_name: "User", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "ACTIVITY-TEST-001",
    )

    OutboxEvent.create!(
      actor: @admin,
      action: "dormitory.resident.created",
      record: resident,
    )

    report = reporting_reports(:new_report)
    OutboxEvent.create!(
      actor: @admin,
      action: "reporting.report.published",
      record: report,
    )

    sign_in_as @dormitory_admin
    get activity_feed_index_path
    assert_response :success

    assert_includes response.body, "добавил(а) проживающего"
    assert_not_includes response.body, "опубликовал(а) отчёт"
  end

  test "admin sees all events" do
    resident = Dormitory::Resident.create!(
      last_name: "Test", first_name: "User", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "ACTIVITY-TEST-002",
    )

    OutboxEvent.create!(
      actor: @admin,
      action: "dormitory.resident.created",
      record: resident,
    )

    report = reporting_reports(:new_report)
    OutboxEvent.create!(
      actor: @admin,
      action: "reporting.report.published",
      record: report,
    )

    sign_in_as @admin
    get activity_feed_index_path
    assert_response :success

    assert_includes response.body, "добавил(а) проживающего"
    assert_includes response.body, "опубликовал(а) отчёт"
  end

  test "user with both reporting.admin and dormitory.admin sees all events" do
    dual_admin = User.create!(email_address: "dual@test.com", password: "password", password_confirmation: "password")
    UserRole.create!(user: dual_admin, role: Role.find_by!(name: "reporting.admin"))
    UserRole.create!(user: dual_admin, role: Role.find_by!(name: "dormitory.admin"))

    resident = Dormitory::Resident.create!(
      last_name: "Test", first_name: "User", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "ACTIVITY-TEST-003",
    )

    OutboxEvent.create!(
      actor: @admin,
      action: "dormitory.resident.created",
      record: resident,
    )

    report = reporting_reports(:new_report)
    OutboxEvent.create!(
      actor: @admin,
      action: "reporting.report.published",
      record: report,
    )

    sign_in_as dual_admin
    get activity_feed_index_path
    assert_response :success

    assert_includes response.body, "добавил(а) проживающего"
    assert_includes response.body, "опубликовал(а) отчёт"
  end
end
