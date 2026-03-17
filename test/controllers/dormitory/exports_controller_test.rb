require "test_helper"

class Dormitory::ExportsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "admin sees settled_residents export page" do
    sign_in @admin
    get dormitory_exports_settled_residents_path
    assert_response :success
  end

  test "admin downloads settled_residents CSV" do
    sign_in @admin
    get dormitory_exports_settled_residents_path(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  test "admin sees free_slots export page" do
    sign_in @admin
    get dormitory_exports_free_slots_path
    assert_response :success
  end

  test "admin downloads free_slots CSV" do
    sign_in @admin
    get dormitory_exports_free_slots_path(format: :csv)
    assert_response :success
  end

  test "admin sees history export page" do
    sign_in @admin
    get dormitory_exports_history_path
    assert_response :success
  end

  test "admin downloads history CSV" do
    sign_in @admin
    get dormitory_exports_history_path(format: :csv)
    assert_response :success
  end

  test "admin sees occupancy_stats export page" do
    sign_in @admin
    get dormitory_exports_occupancy_stats_path
    assert_response :success
  end

  test "admin downloads occupancy_stats CSV" do
    sign_in @admin
    get dormitory_exports_occupancy_stats_path(format: :csv)
    assert_response :success
  end

  test "commandant sees export page" do
    sign_in @commandant
    get dormitory_exports_settled_residents_path
    assert_response :success
  end

  test "manager cannot see export page" do
    sign_in @manager
    get dormitory_exports_settled_residents_path
    assert_response :redirect
  end
end
