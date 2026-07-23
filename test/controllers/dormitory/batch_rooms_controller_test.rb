require "test_helper"

class Dormitory::BatchRoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @building = dormitory_buildings(:building_one)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "new requires auth" do
    get new_dormitory_batch_room_path
    assert_redirected_to new_session_path
  end

  test "new denied for manager" do
    sign_in @manager
    get new_dormitory_batch_room_path
    assert_redirected_to root_path
  end

  test "new denied for commandant" do
    sign_in @commandant
    get new_dormitory_batch_room_path
    assert_redirected_to root_path
  end

  test "new renders for admin" do
    sign_in @admin
    get new_dormitory_batch_room_path
    assert_response :success
    assert_includes response.body, @building.name
  end

  test "new renders for dormitory.admin" do
    sign_in @dormitory_admin
    get new_dormitory_batch_room_path
    assert_response :success
  end

  test "create requires auth" do
    post dormitory_batch_rooms_path, params: batch_rooms_params
    assert_redirected_to new_session_path
  end

  test "create denied for commandant" do
    sign_in @commandant
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: batch_rooms_params
    end
    assert_redirected_to root_path
  end

  test "create denied for manager" do
    sign_in @manager
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: batch_rooms_params
    end
    assert_redirected_to root_path
  end

  test "create multiple rooms as admin" do
    sign_in @admin
    assert_difference "Dormitory::Room.count", 3 do
      post dormitory_batch_rooms_path, params: batch_rooms_params
    end
    assert_redirected_to dormitory_rooms_path(building_id: @building.id)
    assert_equal I18n.t("views.dormitory.batch_rooms.created", count: 3), flash[:notice]
  end

  test "create rooms with gender_restriction" do
    sign_in @admin
    assert_difference "Dormitory::Room.count", 2 do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: @building.id, floor: "5", number: "501", capacity: "2", gender_restriction: "male" },
          { building_id: @building.id, floor: "5", number: "502", capacity: "3", gender_restriction: "female" }
        ]
      }
    end
    room_male = Dormitory::Room.find_by(number: "501")
    room_female = Dormitory::Room.find_by(number: "502")
    assert_equal "male", room_male.gender_restriction
    assert_equal "female", room_female.gender_restriction
  end

  test "create single room" do
    sign_in @admin
    assert_difference "Dormitory::Room.count", 1 do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: @building.id, floor: "1", number: "103", capacity: "4", gender_restriction: "" }
        ]
      }
    end
    assert_redirected_to dormitory_rooms_path(building_id: @building.id)
    assert_equal I18n.t("views.dormitory.batch_rooms.created", count: 1), flash[:notice]
  end

  test "create with empty rooms array returns error" do
    sign_in @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: { rooms: [] }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("views.dormitory.batch_rooms.errors.no_rooms")
  end

  test "create with duplicate room number fails" do
    existing_room = dormitory_rooms(:room_101)
    sign_in @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: @building.id, floor: "1", number: existing_room.number, capacity: "2", gender_restriction: "" }
        ]
      }
    end
    assert_response :unprocessable_entity
  end

  test "create with floor exceeding building floors_count fails" do
    sign_in @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: @building.id, floor: "99", number: "9901", capacity: "2", gender_restriction: "" }
        ]
      }
    end
    assert_response :unprocessable_entity
  end

  test "create with missing building_id fails" do
    sign_in @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: "", floor: "1", number: "101", capacity: "2", gender_restriction: "" }
        ]
      }
    end
    assert_response :unprocessable_entity
  end

  test "create with duplicate numbers in request succeeds for different buildings" do
    building_two = dormitory_buildings(:building_two)
    sign_in @admin
    assert_difference "Dormitory::Room.count", 2 do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: @building.id, floor: "5", number: "500", capacity: "2", gender_restriction: "" },
          { building_id: building_two.id, floor: "1", number: "500", capacity: "2", gender_restriction: "" }
        ]
      }
    end
    assert_equal 2, Dormitory::Room.where(number: "500").count
  end

  test "create with gender_restriction blank saves as nil" do
    sign_in @admin
    post dormitory_batch_rooms_path, params: {
      rooms: [
        { building_id: @building.id, floor: "4", number: "401", capacity: "2", gender_restriction: "" }
      ]
    }
    room = Dormitory::Room.find_by(number: "401")
    assert_nil room.gender_restriction
  end

  test "new pre-selects building from query param" do
    sign_in @admin
    get new_dormitory_batch_room_path, params: { building_id: @building.id }
    assert_response :success
    assert_includes response.body, "selected"
  end

  test "create with non-existent building_id fails" do
    sign_in @admin
    assert_no_difference "Dormitory::Room.count" do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: "999999", floor: "1", number: "101", capacity: "2", gender_restriction: "" }
        ]
      }
    end
    assert_response :unprocessable_entity
  end

  test "create with invalid gender value is sanitized to nil" do
    sign_in @admin
    assert_difference "Dormitory::Room.count", 1 do
      post dormitory_batch_rooms_path, params: {
        rooms: [
          { building_id: @building.id, floor: "2", number: "299", capacity: "2", gender_restriction: "hacked" }
        ]
      }
    end
    room = Dormitory::Room.find_by(number: "299")
    assert_nil room.gender_restriction
  end

  private

  def batch_rooms_params
    {
      rooms: [
        { building_id: @building.id, floor: "3", number: "301", capacity: "2", gender_restriction: "" },
        { building_id: @building.id, floor: "3", number: "302", capacity: "2", gender_restriction: "" },
        { building_id: @building.id, floor: "3", number: "303", capacity: "2", gender_restriction: "" }
      ]
    }
  end
end
