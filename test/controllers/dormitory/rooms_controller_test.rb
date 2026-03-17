require "test_helper"

class Dormitory::RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @building = dormitory_buildings(:building_one)
    @room = dormitory_rooms(:room_101)
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "index requires auth" do
    get dormitory_rooms_path
    assert_redirected_to new_session_path
  end

  test "index denied for manager" do
    sign_in_as @manager
    get dormitory_rooms_path
    assert_redirected_to root_path
  end

  test "index renders for admin" do
    sign_in_as @admin
    get dormitory_rooms_path
    assert_response :success
  end

  test "index renders for dormitory.admin" do
    sign_in_as @dormitory_admin
    get dormitory_rooms_path
    assert_response :success
  end

  test "index renders for commandant" do
    sign_in_as @commandant
    get dormitory_rooms_path
    assert_response :success
  end

  test "index filters by building_id" do
    sign_in_as @admin
    get dormitory_rooms_path, params: { building_id: @building.id }
    assert_response :success
  end

  test "show renders" do
    sign_in_as @admin
    get dormitory_room_path(@room)
    assert_response :success
  end

  test "new renders" do
    sign_in_as @admin
    get new_dormitory_room_path
    assert_response :success
  end

  test "new denied for commandant" do
    sign_in_as @commandant
    get new_dormitory_room_path
    assert_redirected_to root_path
  end

  test "create room with valid params" do
    sign_in_as @admin
    assert_difference "Dormitory::Room.count", 1 do
      post dormitory_rooms_path, params: {
        dormitory_room: { number: "301", building_id: @building.id, floor: 3, capacity: 2 }
      }
    end
    assert_redirected_to dormitory_room_path(Dormitory::Room.last)
    assert_equal I18n.t("dormitory.rooms.created"), flash[:notice]
  end

  test "create room with duplicate number in same building fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_rooms_path, params: {
        dormitory_room: { number: @room.number, building_id: @building.id, floor: 1, capacity: 2 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "create room with invalid floor fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_rooms_path, params: {
        dormitory_room: { number: "901", building_id: @building.id, floor: 99, capacity: 2 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "create room denied for commandant" do
    sign_in_as @commandant
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_rooms_path, params: {
        dormitory_room: { number: "301", building_id: @building.id, floor: 3, capacity: 2 }
      }
    end
    assert_redirected_to root_path
  end

  test "edit renders" do
    sign_in_as @admin
    get edit_dormitory_room_path(@room)
    assert_response :success
  end

  test "update room with valid params" do
    sign_in_as @admin
    patch dormitory_room_path(@room), params: {
      dormitory_room: { capacity: 4 }
    }
    assert_redirected_to dormitory_room_path(@room)
    assert_equal 4, @room.reload.capacity
  end

  test "update room with capacity below occupancy fails" do
    occupied_room = dormitory_rooms(:room_201)
    sign_in_as @admin
    patch dormitory_room_path(occupied_room), params: {
      dormitory_room: { capacity: 1 }
    }
    assert_response :unprocessable_entity
  end

  test "destroy free empty room" do
    sign_in_as @admin
    assert_difference "Dormitory::Room.kept.count", -1 do
      delete dormitory_room_path(@room)
    end
    assert_redirected_to dormitory_rooms_path
    assert @room.reload.discarded?
  end

  test "destroy room with occupants fails" do
    occupied_room = dormitory_rooms(:room_201)
    sign_in_as @admin
    assert_no_difference "Dormitory::Room.kept.count" do
      delete dormitory_room_path(occupied_room)
    end
    assert_redirected_to dormitory_room_path(occupied_room)
  end

  test "destroy denied for commandant" do
    sign_in_as @commandant
    assert_no_difference "Dormitory::Room.kept.count" do
      delete dormitory_room_path(@room)
    end
    assert_redirected_to root_path
  end

  test "suggest_number returns json" do
    sign_in_as @admin
    get suggest_number_dormitory_rooms_path, params: { building_id: @building.id, floor: 1 }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "103", json["number"]
  end

  test "suggest_number for empty floor" do
    sign_in_as @admin
    get suggest_number_dormitory_rooms_path, params: { building_id: @building.id, floor: 4 }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "401", json["number"]
  end
end
