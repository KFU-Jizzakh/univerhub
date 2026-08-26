require "test_helper"

class Dormitory::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @commandant = users(:dormitory_commandant_user)
    @registrar = users(:dormitory_registrar_user)
    @regular_user = users(:visitor_user)
  end

  test "admin can access dashboard" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success
  end

  test "commandant can access dashboard" do
    sign_in_as @commandant
    get dormitory_dashboard_path
    assert_response :success
  end

  test "registrar can access dashboard" do
    sign_in_as @registrar
    get dormitory_dashboard_path
    assert_response :success
  end

  test "regular user cannot access dashboard" do
    sign_in_as @regular_user
    get dormitory_dashboard_path
    assert_redirected_to root_path
  end

  test "dashboard calculates metrics correctly" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select "h1", text: "Дашборд общежития"
    assert_select ".card", minimum: 6
  end

  test "dashboard shows total beds metric" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card", text: /Всего мест/ do
      assert_select ".h2", text: /\A\d+\z/
    end
  end

  test "dashboard shows total debt metric" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card .text-muted", text: "Общий долг"
  end

  test "dashboard shows debt by building when debt exists" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update!(status: :active, required_amount: 10000)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card-header", text: "Долг по корпусам"
  end

  test "dashboard excludes discarded accommodations from overdue list" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update_columns(planned_end_date: Date.current - 1.day)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success
    assert_includes @response.body, acc.resident.full_name

    acc.update_columns(discarded_at: Time.current)
    get dormitory_dashboard_path
    assert_response :success
    assert_not_includes @response.body, acc.resident.full_name
  end

  test "dashboard excludes discarded accommodations from debt calculation" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update!(required_amount: 10000)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success
    assert_select ".card-header", text: "Долг по корпусам", count: 1

    acc.update_columns(discarded_at: Time.current)
    get dormitory_dashboard_path
    assert_response :success
    assert_select ".card-header", text: "Долг по корпусам", count: 0
  end
end
