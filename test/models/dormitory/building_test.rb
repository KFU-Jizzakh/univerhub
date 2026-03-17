require "test_helper"

class Dormitory::BuildingTest < ActiveSupport::TestCase
  test "valid building with all required fields" do
    building = Dormitory::Building.new(name: "Корпус А", address: "ул. Ленина, 1", floors_count: 3)
    assert building.valid?
  end

  test "invalid without name" do
    building = Dormitory::Building.new(address: "ул. Ленина, 1", floors_count: 3)
    assert_not building.valid?
    assert_predicate building.errors[:name], :any?
  end

  test "invalid without address" do
    building = Dormitory::Building.new(name: "Корпус А", floors_count: 3)
    assert_not building.valid?
    assert_predicate building.errors[:address], :any?
  end

  test "invalid with floors_count less than 1" do
    building = Dormitory::Building.new(name: "Корпус А", address: "ул. Ленина, 1", floors_count: 0)
    assert_not building.valid?
    assert_predicate building.errors[:floors_count], :any?
  end

  test "invalid with non-integer floors_count" do
    building = Dormitory::Building.new(name: "Корпус А", address: "ул. Ленина, 1", floors_count: 1.5)
    assert_not building.valid?
    assert_predicate building.errors[:floors_count], :any?
  end

  test "invalid with duplicate name" do
    Dormitory::Building.create!(name: "Корпус А", address: "ул. Ленина, 1", floors_count: 3)
    duplicate = Dormitory::Building.new(name: "Корпус А", address: "ул. Другая, 2", floors_count: 5)
    assert_not duplicate.valid?
    assert_predicate duplicate.errors[:name], :any?
  end

  test "discard sets discarded_at" do
    building = dormitory_buildings(:building_one)
    assert_not building.discarded?
    building.discard!
    assert building.discarded?
  end

  test "kept scope excludes discarded buildings" do
    building = dormitory_buildings(:building_one)
    building.discard!
    assert_not_includes Dormitory::Building.kept, building
    assert_includes Dormitory::Building.with_discarded, building
  end

  test "ordered scope sorts by name" do
    building_b = Dormitory::Building.create!(name: "Блок Б", address: "ул. Б, 2", floors_count: 2)
    building_a = Dormitory::Building.create!(name: "Блок А", address: "ул. А, 1", floors_count: 3)
    assert_equal [ building_a, building_b ], Dormitory::Building.where(id: [ building_a.id, building_b.id ]).ordered
  end

  test "do_discard! fails when building has rooms" do
    building = dormitory_buildings(:building_one)
    assert building.rooms.kept.exists?
    assert_raises(ActiveRecord::RecordInvalid) { building.do_discard! }
    assert_not building.reload.discarded?
  end

  test "do_discard! succeeds when building has no rooms" do
    building = Dormitory::Building.create!(name: "Пустой корпус", address: "ул. Пустая, 1", floors_count: 1)
    assert_nothing_raised { building.do_discard! }
    assert building.reload.discarded?
  end
end
