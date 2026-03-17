require "test_helper"

class Dormitory::RoomTest < ActiveSupport::TestCase
  setup do
    @building = dormitory_buildings(:building_one)
    @admin = users(:admin_user)
    Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown do
    Current.reset
  end

  test "valid room with all required fields" do
    room = Dormitory::Room.new(number: "301", building: @building, floor: 3, capacity: 2)
    assert room.valid?
  end

  test "invalid without number" do
    room = Dormitory::Room.new(building: @building, floor: 1, capacity: 2)
    assert_not room.valid?
    assert_predicate room.errors[:number], :any?
  end

  test "invalid without building" do
    room = Dormitory::Room.new(number: "101", floor: 1, capacity: 2)
    assert_not room.valid?
    assert_predicate room.errors[:building], :any?
  end

  test "invalid without floor" do
    room = Dormitory::Room.new(number: "101", building: @building, capacity: 2)
    assert_not room.valid?
    assert_predicate room.errors[:floor], :any?
  end

  test "invalid with floor less than 1" do
    room = Dormitory::Room.new(number: "101", building: @building, floor: 0, capacity: 2)
    assert_not room.valid?
    assert_predicate room.errors[:floor], :any?
  end

  test "invalid with floor greater than building floors_count" do
    room = Dormitory::Room.new(number: "601", building: @building, floor: 6, capacity: 2)
    assert_not room.valid?
    assert_predicate room.errors[:floor], :any?
  end

  test "invalid without capacity" do
    room = Dormitory::Room.new(number: "101", building: @building, floor: 1, capacity: nil)
    assert_not room.valid?
    assert_predicate room.errors[:capacity], :any?
  end

  test "invalid with capacity less than 1" do
    room = Dormitory::Room.new(number: "101", building: @building, floor: 1, capacity: 0)
    assert_not room.valid?
    assert_predicate room.errors[:capacity], :any?
  end

  test "valid with floor equal to building floors_count" do
    room = Dormitory::Room.new(number: "501", building: @building, floor: 5, capacity: 2)
    assert room.valid?
  end

  test "invalid with duplicate number in same building" do
    room = Dormitory::Room.new(number: "101", building: @building, floor: 1, capacity: 2)
    assert_not room.valid?
    assert_predicate room.errors[:number], :any?
  end

  test "valid with same number in different building" do
    new_building = Dormitory::Building.create!(name: "Новый корпус", address: "ул. Новая, 5", floors_count: 3)
    room = Dormitory::Room.new(number: "101", building: new_building, floor: 1, capacity: 2)
    assert room.valid?
  end

  test "initial status is free" do
    room = Dormitory::Room.new(number: "301", building: @building, floor: 3, capacity: 2)
    assert room.free?
  end

  test "initial current_occupancy is 0" do
    room = Dormitory::Room.new(number: "301", building: @building, floor: 3, capacity: 2)
    assert_equal 0, room.current_occupancy
  end

  test "cannot reduce capacity below current_occupancy on update" do
    room = dormitory_rooms(:room_201)
    room.capacity = 1
    assert_not room.valid?
    assert_predicate room.errors[:capacity], :any?
  end

  test "can reduce capacity to equal current_occupancy" do
    room = dormitory_rooms(:room_201)
    room.capacity = 2
    assert room.valid?
  end

  test "gender_restriction enum values" do
    room = Dormitory::Room.new(number: "301", building: @building, floor: 3, capacity: 2, gender_restriction: :male)
    assert room.valid?
    assert room.male?

    room.gender_restriction = :female
    assert room.female?
  end

  test "gender_restriction can be nil" do
    room = Dormitory::Room.new(number: "301", building: @building, floor: 3, capacity: 2, gender_restriction: nil)
    assert room.valid?
  end

  test "do_create! creates OutboxEvent" do
    room = Dormitory::Room.new(number: "301", building: @building, floor: 3, capacity: 2)
    assert_difference "OutboxEvent.count", 1 do
      room.do_create!
    end
    assert_equal "dormitory.room.created", OutboxEvent.last.action
  end

  test "do_update! creates OutboxEvent" do
    room = dormitory_rooms(:room_101)
    assert_difference "OutboxEvent.count", 1 do
      room.do_update!(capacity: 4)
    end
    assert_equal 4, room.reload.capacity
  end

  test "do_discard! discards free empty room" do
    room = dormitory_rooms(:room_101)
    assert_difference "OutboxEvent.count", 1 do
      room.do_discard!
    end
    assert room.reload.discarded?
  end

  test "do_discard! fails for room with occupants" do
    room = dormitory_rooms(:room_201)
    assert_not room.empty?
    assert_no_difference "OutboxEvent.count" do
      assert_raises(ActiveRecord::RecordInvalid) { room.do_discard! }
    end
  end

  test "do_discard! fails for non-free room" do
    room = dormitory_rooms(:room_101)
    room.update_column(:status, "fully_occupied")
    assert_no_difference "OutboxEvent.count" do
      assert_raises(ActiveRecord::RecordInvalid) { room.do_discard! }
    end
  end

  test "discard sets discarded_at" do
    room = dormitory_rooms(:room_102)
    room.discard!
    assert room.discarded?
    assert_not_nil room.discarded_at
  end

  test "kept scope excludes discarded rooms" do
    room = dormitory_rooms(:room_101)
    room.discard!
    assert_not_includes Dormitory::Room.kept, room
    assert_includes Dormitory::Room.with_discarded, room
  end

  test "ordered scope sorts by floor and number" do
    rooms = Dormitory::Room.kept.where(building: @building).ordered
    assert_equal "101", rooms.first.number
  end

  test "suggested_number returns next available" do
    room = Dormitory::Room.new(building: @building, floor: 1)
    assert_equal "103", room.suggested_number
  end

  test "suggested_number for empty floor" do
    room = Dormitory::Room.new(building: @building, floor: 4)
    assert_equal "401", room.suggested_number
  end

  test "suggested_number returns nil without building" do
    room = Dormitory::Room.new(floor: 1)
    assert_nil room.suggested_number
  end

  test "duplicate number allowed for discarded room" do
    room = dormitory_rooms(:room_101)
    room.discard!
    new_room = Dormitory::Room.new(number: "101", building: @building, floor: 1, capacity: 2)
    assert new_room.valid?
  end

  test "AASM occupy transition from free to partially_occupied" do
    room = dormitory_rooms(:room_101)
    room.update_column(:current_occupancy, 1)
    room.occupy!
    assert room.partially_occupied?
  end

  test "AASM occupy transition from free to fully_occupied" do
    room = dormitory_rooms(:room_101)
    room.update_column(:current_occupancy, room.capacity)
    room.occupy!
    assert room.fully_occupied?
  end
end
