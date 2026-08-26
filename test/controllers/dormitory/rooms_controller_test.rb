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

  test "index displays bed statistics summary" do
    sign_in_as @admin
    get dormitory_rooms_path
    assert_response :success
    assert_select ".card", text: /Всего мест/
    assert_select ".card", text: /Занято мест/
    assert_select ".card", text: /Свободно мест/
    assert_select ".card", text: /Заселённость/
  end

  test "index shows available slots column" do
    sign_in_as @admin
    get dormitory_rooms_path
    assert_response :success
    assert_select "th", text: /Свободных мест/
  end

  test "show displays available slots and occupancy percentage" do
    sign_in_as @admin
    get dormitory_room_path(@room)
    assert_response :success
    assert_select ".info-item", text: /Свободных мест/
    assert_select ".info-item", text: /Заполненность/
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

  test "show excludes discarded accommodations from room list" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.discard!

    sign_in_as @admin
    get dormitory_room_path(dormitory_rooms(:room_201))
    assert_response :success
    assert_not_includes @response.body, acc.resident.full_name
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

  test "available returns free and partially occupied rooms with free_bed_labels" do
    sign_in_as @admin
    get available_dormitory_rooms_path, params: { building_id: @building.id }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    room = json.find { |r| r["id"] == dormitory_rooms(:room_201).id }
    assert room.present?
    assert_equal [ "B", "C", "D" ], room["free_bed_labels"]
  end

  test "available precomputes free bed labels without per-room queries" do
    sign_in_as @admin
    assert_queries_count 5 do
      get available_dormitory_rooms_path, params: { building_id: @building.id }, as: :json
    end
    assert_response :success
  end

  test "available filters rooms by course" do
    room_101 = dormitory_rooms(:room_101)
    room_101.update!(allowed_courses: [ 5 ])
    sign_in_as @admin

    get available_dormitory_rooms_path, params: { course: "1" }, as: :json
    json = JSON.parse(response.body)
    assert_not_includes json.map { |r| r["id"] }, room_101.id

    get available_dormitory_rooms_path, params: { course: "5" }, as: :json
    json = JSON.parse(response.body)
    assert_includes json.map { |r| r["id"] }, room_101.id
  end

  test "available with out-of-range course ignores the filter" do
    room_101 = dormitory_rooms(:room_101)
    room_101.update!(allowed_courses: [ 5 ])
    sign_in_as @admin

    get available_dormitory_rooms_path, params: { course: "9" }, as: :json
    json = JSON.parse(response.body)
    assert_includes json.map { |r| r["id"] }, room_101.id
  end

  test "available denied for manager" do
    sign_in_as @manager
    get available_dormitory_rooms_path, as: :json
    assert_redirected_to root_path
  end

  test "beds returns free bed labels" do
    sign_in_as @admin
    get beds_dormitory_rooms_path, params: { id: dormitory_rooms(:room_201).id }, as: :json
    assert_response :success
    assert_equal [ "B", "C", "D" ], JSON.parse(response.body)
  end

  test "beds denied for manager" do
    sign_in_as @manager
    get beds_dormitory_rooms_path, params: { id: dormitory_rooms(:room_101).id }, as: :json
    assert_redirected_to root_path
  end
end
