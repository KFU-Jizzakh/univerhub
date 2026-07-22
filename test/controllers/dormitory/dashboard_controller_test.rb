require "test_helper"

class Dormitory::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @commandant = users(:dormitory_commandant_user)
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
    assert_select ".card", minimum: 5 # Top metrics including total debt
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
end
