require "test_helper"

class Dormitory::ViolationPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @registrar = users(:dormitory_registrar_user)
    @manager = users(:manager_user)
    @violation = dormitory_violations(:violation_open_noise)
  end

  test "index? allowed for registrar" do
    assert Dormitory::ViolationPolicy.new(@registrar, Dormitory::Violation).index?
  end

  test "show? allowed for registrar" do
    assert Dormitory::ViolationPolicy.new(@registrar, @violation).show?
  end

  test "create? denied for registrar" do
    assert_not Dormitory::ViolationPolicy.new(@registrar, Dormitory::Violation).create?
  end

  test "update? denied for registrar" do
    assert_not Dormitory::ViolationPolicy.new(@registrar, @violation).update?
  end

  test "destroy? denied for registrar" do
    assert_not Dormitory::ViolationPolicy.new(@registrar, @violation).destroy?
  end

  test "index? allowed for admin" do
    assert Dormitory::ViolationPolicy.new(@admin, Dormitory::Violation).index?
  end

  test "index? allowed for dormitory_admin" do
    assert Dormitory::ViolationPolicy.new(@dormitory_admin, Dormitory::Violation).index?
  end

  test "index? allowed for commandant" do
    assert Dormitory::ViolationPolicy.new(@commandant, Dormitory::Violation).index?
  end

  test "index? denied for manager" do
    assert_not Dormitory::ViolationPolicy.new(@manager, Dormitory::Violation).index?
  end

  test "show? allowed for admin" do
    assert Dormitory::ViolationPolicy.new(@admin, @violation).show?
  end

  test "show? allowed for dormitory_admin" do
    assert Dormitory::ViolationPolicy.new(@dormitory_admin, @violation).show?
  end

  test "show? allowed for commandant" do
    assert Dormitory::ViolationPolicy.new(@commandant, @violation).show?
  end

  test "show? denied for manager" do
    assert_not Dormitory::ViolationPolicy.new(@manager, @violation).show?
  end

  test "create? allowed for admin" do
    assert Dormitory::ViolationPolicy.new(@admin, Dormitory::Violation).create?
  end

  test "create? allowed for commandant" do
    assert Dormitory::ViolationPolicy.new(@commandant, Dormitory::Violation).create?
  end

  test "create? denied for manager" do
    assert_not Dormitory::ViolationPolicy.new(@manager, Dormitory::Violation).create?
  end

  test "update? allowed for admin" do
    assert Dormitory::ViolationPolicy.new(@admin, @violation).update?
  end

  test "update? allowed for dormitory_admin" do
    assert Dormitory::ViolationPolicy.new(@dormitory_admin, @violation).update?
  end

  test "update? allowed for commandant" do
    assert Dormitory::ViolationPolicy.new(@commandant, @violation).update?
  end

  test "destroy? allowed for admin" do
    assert Dormitory::ViolationPolicy.new(@admin, @violation).destroy?
  end

  test "destroy? allowed for dormitory_admin" do
    assert Dormitory::ViolationPolicy.new(@dormitory_admin, @violation).destroy?
  end

  test "destroy? allowed for commandant" do
    assert Dormitory::ViolationPolicy.new(@commandant, @violation).destroy?
  end

  test "destroy? denied for manager" do
    assert_not Dormitory::ViolationPolicy.new(@manager, @violation).destroy?
  end

  test "scope resolves all for admin" do
    scope = Dormitory::ViolationPolicy::Scope.new(@admin, Dormitory::Violation.kept).resolve
    assert_equal Dormitory::Violation.kept.count, scope.count
  end

  test "scope resolves all for dormitory_admin" do
    scope = Dormitory::ViolationPolicy::Scope.new(@dormitory_admin, Dormitory::Violation.kept).resolve
    assert_equal Dormitory::Violation.kept.count, scope.count
  end

  test "scope resolves none for manager" do
    scope = Dormitory::ViolationPolicy::Scope.new(@manager, Dormitory::Violation.kept).resolve
    assert_equal 0, scope.count
  end

  test "scope resolves all for registrar" do
    scope = Dormitory::ViolationPolicy::Scope.new(@registrar, Dormitory::Violation.kept).resolve
    assert_equal Dormitory::Violation.kept.count, scope.count
  end
end
