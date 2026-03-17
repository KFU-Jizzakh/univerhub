require "test_helper"

class Dormitory::RoomPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @room = dormitory_rooms(:room_101)
  end

  def policy(user, record)
    Dormitory::RoomPolicy.new(user, record)
  end

  test "index? allowed for admin" do
    assert policy(@admin, Dormitory::Room).index?
  end

  test "index? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, Dormitory::Room).index?
  end

  test "index? allowed for commandant" do
    assert policy(@commandant, Dormitory::Room).index?
  end

  test "index? denied for manager" do
    assert_not policy(@manager, Dormitory::Room).index?
  end

  test "show? allowed for admin" do
    assert policy(@admin, @room).show?
  end

  test "show? allowed for commandant" do
    assert policy(@commandant, @room).show?
  end

  test "create? allowed for admin" do
    assert policy(@admin, @room).create?
  end

  test "create? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, @room).create?
  end

  test "create? denied for commandant" do
    assert_not policy(@commandant, @room).create?
  end

  test "update? allowed for admin" do
    assert policy(@admin, @room).update?
  end

  test "update? denied for commandant" do
    assert_not policy(@commandant, @room).update?
  end

  test "destroy? allowed for admin" do
    assert policy(@admin, @room).destroy?
  end

  test "destroy? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, @room).destroy?
  end

  test "destroy? denied for commandant" do
    assert_not policy(@commandant, @room).destroy?
  end

  test "suggest_number? allowed for admin" do
    assert policy(@admin, Dormitory::Room).suggest_number?
  end

  test "suggest_number? denied for commandant" do
    assert_not policy(@commandant, Dormitory::Room).suggest_number?
  end

  test "scope resolves to kept ordered rooms for admin" do
    scope = Dormitory::RoomPolicy::Scope.new(@admin, Dormitory::Room)
    rooms = scope.resolve
    assert_includes rooms, @room
  end

  test "scope resolves to kept ordered rooms for commandant" do
    scope = Dormitory::RoomPolicy::Scope.new(@commandant, Dormitory::Room)
    rooms = scope.resolve
    assert_includes rooms, @room
  end

  test "scope resolves to none for manager" do
    scope = Dormitory::RoomPolicy::Scope.new(@manager, Dormitory::Room)
    assert_empty scope.resolve
  end
end
