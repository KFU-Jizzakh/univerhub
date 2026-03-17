require "test_helper"

class Dormitory::CommandantBuildingTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  test "creates valid active assignment" do
    user = users(:dormitory_commandant_user)
    new_building = Dormitory::Building.create!(name: "Новый корпус", address: "ул. Новая, 1", floors_count: 1)

    cb = Dormitory::CommandantBuilding.new(user: user, building: new_building)
    assert cb.valid?
  end

  test "requires user" do
    building = dormitory_buildings(:building_one)
    cb = Dormitory::CommandantBuilding.new(building: building)
    assert_not cb.valid?
    assert_predicate cb.errors[:user], :any?
  end

  test "requires building" do
    user = users(:dormitory_commandant_user)
    cb = Dormitory::CommandantBuilding.new(user: user)
    assert_not cb.valid?
    assert_predicate cb.errors[:building], :any?
  end

  test "prevents duplicate active assignment for same user and building" do
    existing = dormitory_commandant_buildings(:commandant_building_one)
    cb = Dormitory::CommandantBuilding.new(user: existing.user, building: existing.building)
    assert_not cb.valid?
    assert_predicate cb.errors[:building_id], :any?
  end

  test "allows re-assignment after deactivation" do
    existing = dormitory_commandant_buildings(:commandant_building_one)
    existing.do_deactivate!

    cb = Dormitory::CommandantBuilding.new(user: existing.user, building: existing.building)
    assert cb.valid?
  end

  test "active scope returns only active assignments" do
    active = dormitory_commandant_buildings(:commandant_building_one)
    deactivated = dormitory_commandant_buildings(:commandant_building_two)
    deactivated.update!(deactivated_at: Time.current)

    scope_ids = Dormitory::CommandantBuilding.active.ids
    assert_includes scope_ids, active.id
    assert_not_includes scope_ids, deactivated.id
  end

  test "deactivated scope returns only deactivated assignments" do
    active = dormitory_commandant_buildings(:commandant_building_one)
    deactivated = dormitory_commandant_buildings(:commandant_building_two)
    deactivated.update!(deactivated_at: Time.current)

    scope_ids = Dormitory::CommandantBuilding.deactivated.ids
    assert_includes scope_ids, deactivated.id
    assert_not_includes scope_ids, active.id
  end

  test "deactivate! sets deactivated_at" do
    cb = dormitory_commandant_buildings(:commandant_building_one)
    assert cb.active?

    freeze_time do
      cb.do_deactivate!
      assert_equal Time.current, cb.deactivated_at
      assert_not cb.active?
    end
  end

  test "allows multiple buildings for same user" do
    user = users(:dormitory_commandant_user)
    assert_equal 2, user.commandant_buildings.active.count
  end

  test "do_create! creates assignment and OutboxEvent" do
    user = users(:dormitory_commandant_user)
    new_building = Dormitory::Building.create!(name: "Корпус В", address: "ул. В, 3", floors_count: 2)
    cb = Dormitory::CommandantBuilding.new(user: user, building: new_building)

    assert_difference "Dormitory::CommandantBuilding.count", 1 do
      assert_difference "OutboxEvent.count", 1 do
        cb.do_create!
      end
    end

    assert_equal "dormitory.commandant_building.created", OutboxEvent.last.action
    assert_equal cb, OutboxEvent.last.record
  end

  test "do_update! updates assignment and creates OutboxEvent" do
    cb = dormitory_commandant_buildings(:commandant_building_one)
    new_building = Dormitory::Building.create!(name: "Корпус Г", address: "ул. Г, 4", floors_count: 3)

    assert_difference "OutboxEvent.count", 1 do
      cb.do_update!(building_id: new_building.id)
    end

    assert_equal new_building, cb.reload.building
    assert_equal "dormitory.commandant_building.updated", OutboxEvent.last.action
  end

  test "do_deactivate! deactivates and creates OutboxEvent" do
    cb = dormitory_commandant_buildings(:commandant_building_one)
    assert cb.active?

    assert_difference "OutboxEvent.count", 1 do
      cb.do_deactivate!
    end

    assert_not cb.reload.active?
    assert_equal "dormitory.commandant_building.deactivated", OutboxEvent.last.action
  end

  test "do_destroy! destroys assignment and creates OutboxEvent" do
    cb = dormitory_commandant_buildings(:commandant_building_one)

    assert_difference "Dormitory::CommandantBuilding.count", -1 do
      assert_difference "OutboxEvent.count", 1 do
        cb.do_destroy!
      end
    end

    assert_equal "dormitory.commandant_building.destroyed", OutboxEvent.last.action
  end
end
