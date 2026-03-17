require "test_helper"

class Dormitory::AcademicYearPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @year = dormitory_academic_years(:active_year_2025_2026)
  end

  test "admin can index" do
    assert Dormitory::AcademicYearPolicy.new(@admin, Dormitory::AcademicYear).index?
  end

  test "dormitory_admin can index" do
    assert Dormitory::AcademicYearPolicy.new(@dormitory_admin, Dormitory::AcademicYear).index?
  end

  test "commandant can index" do
    assert Dormitory::AcademicYearPolicy.new(@commandant, Dormitory::AcademicYear).index?
  end

  test "manager cannot index" do
    assert_not Dormitory::AcademicYearPolicy.new(@manager, Dormitory::AcademicYear).index?
  end

  test "admin can create" do
    year = Dormitory::AcademicYear.new
    assert Dormitory::AcademicYearPolicy.new(@admin, year).create?
  end

  test "commandant cannot create" do
    year = Dormitory::AcademicYear.new
    assert_not Dormitory::AcademicYearPolicy.new(@commandant, year).create?
  end

  test "admin can update" do
    assert Dormitory::AcademicYearPolicy.new(@admin, @year).update?
  end

  test "commandant cannot update" do
    assert_not Dormitory::AcademicYearPolicy.new(@commandant, @year).update?
  end

  test "admin can destroy" do
    assert Dormitory::AcademicYearPolicy.new(@admin, @year).destroy?
  end

  test "dormitory_admin can destroy" do
    assert Dormitory::AcademicYearPolicy.new(@dormitory_admin, @year).destroy?
  end

  test "commandant cannot destroy" do
    assert_not Dormitory::AcademicYearPolicy.new(@commandant, @year).destroy?
  end

  test "scope resolves for commandant" do
    scope = Dormitory::AcademicYearPolicy::Scope.new(@commandant, Dormitory::AcademicYear.all).resolve
    assert scope.any?
  end

  test "scope resolves to none for manager" do
    scope = Dormitory::AcademicYearPolicy::Scope.new(@manager, Dormitory::AcademicYear.all).resolve
    assert_empty scope
  end
end
