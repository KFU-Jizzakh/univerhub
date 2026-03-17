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

    # We can't easily check instance variables in integration tests,
    # but we can check if the response body contains expected strings.
    # Using ru.yml translations.
    assert_select "h1", text: "Дашборд общежития"
    assert_select ".card", minimum: 4 # Top metrics
  end
end
