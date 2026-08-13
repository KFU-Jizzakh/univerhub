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

  test "allowed_courses accepts values within 1..6" do
    room = Dormitory::Room.new(number: "105", building: @building, floor: 1, capacity: 2, allowed_courses: [ 1, 3, 6 ])
    assert room.valid?
  end

  test "allowed_courses rejects values outside 1..6" do
    room = Dormitory::Room.new(number: "106", building: @building, floor: 1, capacity: 2, allowed_courses: [ 1, 7 ])
    assert_not room.valid?
    assert_predicate room.errors[:allowed_courses], :any?
  end

  test "empty allowed_courses is normalized to nil on validation" do
    room = Dormitory::Room.new(number: "107", building: @building, floor: 1, capacity: 2, allowed_courses: [])
    assert room.valid?
    assert_nil room.allowed_courses
  end

  test "bed_labels returns letters up to capacity" do
    room = Dormitory::Room.new(number: "107", building: @building, floor: 1, capacity: 3)
    assert_equal [ "A", "B", "C" ], room.bed_labels
  end

  test "label_for maps index to letter" do
    assert_equal "A", Dormitory::Room.label_for(0)
    assert_equal "C", Dormitory::Room.label_for(2)
    assert_equal "Z", Dormitory::Room.label_for(25)
    assert_equal "AA", Dormitory::Room.label_for(26)
  end

  test "free_bed_labels returns unoccupied labels" do
    room = dormitory_rooms(:room_101)
    room.update_columns(capacity: 3, current_occupancy: 1)
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_one_not_settled), room: room, course: 3,
      application_number: "З-МЕСТА", contract_number: "Д-МЕСТА",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: "A"
    )
    assert_equal [ "B", "C" ], room.free_bed_labels
  end

  test "free_bed_labels returns no phantom labels in an overcrowded room" do
    room = dormitory_rooms(:room_101)
    room.update_columns(capacity: 2, current_occupancy: 3, status: :overcrowded)
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_one_not_settled), room: room, course: 3,
      application_number: "З-ПЕР1", contract_number: "Д-ПЕР1",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: "A"
    )
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_three_evicted), room: room, course: 3,
      application_number: "З-ПЕР2", contract_number: "Д-ПЕР2",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: nil
    )
    assert_equal [], room.free_bed_labels
  end

  test "free_bed_labels is empty when room is at capacity with an empty label" do
    room = dormitory_rooms(:room_101)
    room.update_columns(capacity: 2, current_occupancy: 2, status: :fully_occupied)
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_one_not_settled), room: room, course: 3,
      application_number: "З-ПОЛН1", contract_number: "Д-ПОЛН1",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: "A"
    )
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_three_evicted), room: room, course: 3,
      application_number: "З-ПОЛН2", contract_number: "Д-ПОЛН2",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: nil
    )
    assert_equal [], room.free_bed_labels
  end

  test "free_bed_labels accepts precomputed occupied labels" do
    room = dormitory_rooms(:room_101)
    room.update_columns(capacity: 3, current_occupancy: 1)
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_one_not_settled), room: room, course: 3,
      application_number: "З-ПРЗ", contract_number: "Д-ПРЗ",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: "A"
    )
    assert_equal [ "B", "C" ], room.free_bed_labels([ "A" ])
  end

  test "occupied_bed_labels_by_room groups occupied labels per room in one pass" do
    room_101 = dormitory_rooms(:room_101)
    room_201 = dormitory_rooms(:room_201)
    room_101.update_columns(capacity: 3, current_occupancy: 1)
    Dormitory::Accommodation.create!(
      resident: dormitory_residents(:resident_one_not_settled), room: room_101, course: 3,
      application_number: "З-ГРП1", contract_number: "Д-ГРП1",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :active, bed_label: "A"
    )

    result = Dormitory::Room.occupied_bed_labels_by_room([ room_101, room_201 ])

    assert_equal [ "A" ], result[room_101.id]
    assert_equal [ "A" ], result[room_201.id]
  end

  test "allows_course? true for unrestricted room" do
    room = dormitory_rooms(:room_101)
    assert room.allows_course?(5)
  end

  test "allows_course? matches allowed_courses" do
    room = dormitory_rooms(:room_101)
    room.update!(allowed_courses: [ 1, 2 ])
    assert room.allows_course?(1)
    assert_not room.allows_course?(5)
  end

  test "best_available_for prefers partially occupied then free, ordered by building, floor, number" do
    male = dormitory_residents(:resident_one_not_settled)
    room = Dormitory::Room.best_available_for(male)
    assert_equal dormitory_rooms(:room_201).id, room.id
  end

  test "candidate_rooms_for returns all compatible rooms in preference order" do
    male = dormitory_residents(:resident_one_not_settled)
    ids = Dormitory::Room.candidate_rooms_for(male).pluck(:id)

    assert_equal dormitory_rooms(:room_201).id, ids.first
    assert_includes ids, dormitory_rooms(:room_101).id
    assert_includes ids, dormitory_rooms(:room_102).id
    assert_operator ids.index(dormitory_rooms(:room_101).id), :<, ids.index(dormitory_rooms(:room_102).id)
  end

  test "candidate_rooms_for excludes gender and course incompatible rooms" do
    room_101 = dormitory_rooms(:room_101)
    room_101.update!(gender_restriction: :female, allowed_courses: [ 5 ])
    male = dormitory_residents(:resident_one_not_settled)

    candidates = Dormitory::Room.candidate_rooms_for(male).to_a

    assert_not_includes candidates, room_101
  end

  test "candidate_rooms_for with nil gender still includes gender-restricted rooms" do
    room_101 = dormitory_rooms(:room_101)
    room_101.update!(gender_restriction: :female)
    candidate = Dormitory::Resident.new(gender: nil, course: nil)

    assert_includes Dormitory::Room.candidate_rooms_for(candidate).to_a, room_101
  end

  test "candidate_rooms_for with nil course still includes course-restricted rooms" do
    room_101 = dormitory_rooms(:room_101)
    room_101.update!(allowed_courses: [ 5 ])
    candidate = Dormitory::Resident.new(course: nil)

    assert_includes Dormitory::Room.candidate_rooms_for(candidate).to_a, room_101
  end

  test "best_available_for filters by course" do
    room = dormitory_rooms(:room_101)
    room.update!(allowed_courses: [ 5 ])
    male = dormitory_residents(:resident_one_not_settled)
    male.course = 1

    found = Dormitory::Room.best_available_for(male)
    assert_not_equal room.id, found.id
  end

  test "available_for filters free rooms by gender and course" do
    room_101 = dormitory_rooms(:room_101)
    room_101.update!(gender_restriction: :female, allowed_courses: [ 1 ])

    males = Dormitory::Room.available_for("male", course: 1)
    assert_not_includes males, room_101

    room_101.update!(gender_restriction: nil)
    males = Dormitory::Room.available_for("male", course: 1)
    assert_includes males, room_101

    males = Dormitory::Room.available_for("male", course: 6)
    assert_not_includes males, room_101
  end
end
