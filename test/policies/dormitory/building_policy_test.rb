require "test_helper"

class Dormitory::BuildingPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @building = dormitory_buildings(:building_one)
  end

  def policy(user, record)
    Dormitory::BuildingPolicy.new(user, record)
  end

  test "index? allowed for admin" do
    assert policy(@admin, Dormitory::Building).index?
  end

  test "index? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, Dormitory::Building).index?
  end

  test "index? denied for commandant" do
    assert policy(@commandant, Dormitory::Building).index?
  end

  test "index? denied for manager" do
    assert_not policy(@manager, Dormitory::Building).index?
  end

  test "create? allowed for admin" do
    assert policy(@admin, @building).create?
  end

  test "create? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, @building).create?
  end

  test "create? denied for commandant" do
    assert_not policy(@commandant, @building).create?
  end

  test "update? allowed for admin" do
    assert policy(@admin, @building).update?
  end

  test "destroy? allowed for admin" do
    assert policy(@admin, @building).destroy?
  end

  test "destroy? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, @building).destroy?
  end

  test "destroy? denied for commandant" do
    assert_not policy(@commandant, @building).destroy?
  end

  test "scope resolves to kept ordered buildings for admin" do
    scope = Dormitory::BuildingPolicy::Scope.new(@admin, Dormitory::Building)
    buildings = scope.resolve
    assert_includes buildings, @building
  end

  test "scope resolves to none for manager" do
    scope = Dormitory::BuildingPolicy::Scope.new(@manager, Dormitory::Building)
    assert_empty scope.resolve
  end

  test "show? allowed for commandant with assigned building" do
    assert policy(@commandant, @building).show?
  end

  test "show? denied for commandant with unassigned building" do
    unassigned = Dormitory::Building.create!(name: "Чужой корпус", address: "ул. Чужая, 1", floors_count: 1)
    assert_not policy(@commandant, unassigned).show?
  end

  test "scope resolves to assigned buildings for commandant" do
    scope = Dormitory::BuildingPolicy::Scope.new(@commandant, Dormitory::Building)
    buildings = scope.resolve
    assert_includes buildings, dormitory_buildings(:building_one)
    assert_includes buildings, dormitory_buildings(:building_two)
    assert_equal 2, buildings.count
  end

  test "update? denied for commandant" do
    assert_not policy(@commandant, @building).update?
  end
end
