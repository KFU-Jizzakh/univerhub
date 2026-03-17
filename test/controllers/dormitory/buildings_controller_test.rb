require "test_helper"

class Dormitory::BuildingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @manager = users(:manager_user)
    @building = dormitory_buildings(:building_one)
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "index requires admin or dormitory.admin" do
    sign_in_as @manager
    get dormitory_buildings_path
    assert_redirected_to root_path
  end

  test "index renders for admin" do
    sign_in_as @admin
    get dormitory_buildings_path
    assert_response :success
  end

  test "index renders for dormitory.admin" do
    sign_in_as @dormitory_admin
    get dormitory_buildings_path
    assert_response :success
  end

  test "show renders" do
    sign_in_as @admin
    get dormitory_building_path(@building)
    assert_response :success
  end

  test "new renders" do
    sign_in_as @admin
    get new_dormitory_building_path
    assert_response :success
  end

  test "create building with valid params" do
    sign_in_as @admin
    assert_difference "Dormitory::Building.count", 1 do
      post dormitory_buildings_path, params: {
        dormitory_building: { name: "Новый корпус", address: "ул. Новая, 10", floors_count: 4, description: "Описание" }
      }
    end
    assert_redirected_to dormitory_building_path(Dormitory::Building.last)
  end

  test "create building with duplicate name fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Building.count" do
      post dormitory_buildings_path, params: {
        dormitory_building: { name: @building.name, address: "ул. Новая, 10", floors_count: 4 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "edit renders" do
    sign_in_as @admin
    get edit_dormitory_building_path(@building)
    assert_response :success
  end

  test "update building with valid params" do
    sign_in_as @admin
    patch dormitory_building_path(@building), params: {
      dormitory_building: { name: "Обновлённый корпус" }
    }
    assert_redirected_to dormitory_building_path(@building)
    assert_equal "Обновлённый корпус", @building.reload.name
  end

  test "update building with duplicate name fails" do
    other = dormitory_buildings(:building_two)
    sign_in_as @admin
    patch dormitory_building_path(@building), params: {
      dormitory_building: { name: other.name }
    }
    assert_response :unprocessable_entity
  end

  test "destroy building without rooms" do
    empty_building = Dormitory::Building.create!(name: "Пустой корпус", address: "ул. Пустая, 1", floors_count: 1)
    sign_in_as @admin
    assert_difference "Dormitory::Building.kept.count", -1 do
      delete dormitory_building_path(empty_building)
    end
    assert_redirected_to dormitory_buildings_path
    assert empty_building.reload.discarded?
  end
end
