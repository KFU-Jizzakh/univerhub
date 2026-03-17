require "test_helper"

class Dormitory::BatchOperationPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @academic_year = dormitory_academic_years(:active_year_2025_2026)
    @building = dormitory_buildings(:building_one)

    @op = Dormitory::BatchOperation.create!(
      academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
    )
  end

  test "admin can new/create/show" do
    assert Dormitory::BatchOperationPolicy.new(@admin, Dormitory::BatchOperation).index?
    assert Dormitory::BatchOperationPolicy.new(@admin, Dormitory::BatchOperation).new?
    assert Dormitory::BatchOperationPolicy.new(@admin, @op).create?
    assert Dormitory::BatchOperationPolicy.new(@admin, @op).show?
  end

  test "commandant can new/create/show" do
    assert Dormitory::BatchOperationPolicy.new(@commandant, Dormitory::BatchOperation).index?
    assert Dormitory::BatchOperationPolicy.new(@commandant, Dormitory::BatchOperation).new?
    assert Dormitory::BatchOperationPolicy.new(@commandant, @op).create?
    assert Dormitory::BatchOperationPolicy.new(@commandant, @op).show?
  end

  test "manager cannot new" do
    assert_not Dormitory::BatchOperationPolicy.new(@manager, Dormitory::BatchOperation).index?
    assert_not Dormitory::BatchOperationPolicy.new(@manager, Dormitory::BatchOperation).new?
  end

  test "scope resolves for commandant to assigned buildings" do
    scope = Dormitory::BatchOperationPolicy::Scope.new(@commandant, Dormitory::BatchOperation.all).resolve
    assert scope.any?
    scope.each do |op|
      assert_includes @commandant.assigned_building_ids, op.building_id
    end
  end

  test "scope resolves to none for manager" do
    scope = Dormitory::BatchOperationPolicy::Scope.new(@manager, Dormitory::BatchOperation.all).resolve
    assert_empty scope
  end
end
