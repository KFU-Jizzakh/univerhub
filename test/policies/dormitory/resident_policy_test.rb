require "test_helper"

class Dormitory::ResidentPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @resident_building_one = dormitory_residents(:resident_one_not_settled)
    @resident_building_two = dormitory_residents(:resident_four_other_building)

    @unassigned_building = Dormitory::Building.create!(
      name: "Неassignовый корпус", address: "ул. Новая, 9", floors_count: 2,
    )
    @room_unassigned = Dormitory::Room.create!(
      number: "999", building: @unassigned_building, floor: 1, capacity: 2,
    )
    @resident_unassigned = Dormitory::Resident.create!(
      last_name: "Чужой", first_name: "Человек", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNASSIGNED1",
    )
    acc = Dormitory::Accommodation.create!(
      resident: @resident_unassigned,
      room: @room_unassigned,
      application_number: "APP-001",
      contract_number: "CNT-001",
      start_date: Date.current,
      planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026)
    )
    acc.application_file.attach(
      io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf",
    )
    acc.contract_file.attach(
      io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf",
    )
    acc.payment_receipt.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf",
    )
    acc.do_settle!
  end

  def policy(user, record)
    Dormitory::ResidentPolicy.new(user, record)
  end

  # index?
  test "index? allowed for admin" do
    assert policy(@admin, Dormitory::Resident).index?
  end

  test "index? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, Dormitory::Resident).index?
  end

  test "index? allowed for commandant" do
    assert policy(@commandant, Dormitory::Resident).index?
  end

  test "index? denied for manager" do
    assert_not policy(@manager, Dormitory::Resident).index?
  end

  # show?
  test "show? allowed for admin" do
    assert policy(@admin, @resident_building_one).show?
  end

  test "show? allowed for commandant in own building" do
    assert policy(@commandant, @resident_building_one).show?
  end

  test "show? allowed for commandant for unsettled resident" do
    unsettled = dormitory_residents(:resident_four_other_building)
    assert policy(@commandant, unsettled).show?
  end

  test "show? denied for commandant in unassigned building" do
    assert_not policy(@commandant, @resident_unassigned).show?
  end

  # create?
  test "create? allowed for admin" do
    assert policy(@admin, Dormitory::Resident).create?
  end

  test "create? allowed for commandant" do
    assert policy(@commandant, Dormitory::Resident).create?
  end

  test "create? denied for manager" do
    assert_not policy(@manager, Dormitory::Resident).create?
  end

  # update?
  test "update? allowed for admin" do
    assert policy(@admin, @resident_building_one).update?
  end

  test "update? allowed for commandant in own building" do
    assert policy(@commandant, @resident_building_one).update?
  end

  test "update? allowed for commandant for unsettled resident" do
    unsettled = dormitory_residents(:resident_four_other_building)
    assert policy(@commandant, unsettled).update?
  end

  test "update? denied for commandant in unassigned building" do
    assert_not policy(@commandant, @resident_unassigned).update?
  end

  # destroy?
  test "destroy? allowed for admin" do
    assert policy(@admin, @resident_building_one).destroy?
  end

  test "destroy? allowed for dormitory.admin" do
    assert policy(@dormitory_admin, @resident_building_one).destroy?
  end

  test "destroy? denied for commandant" do
    assert_not policy(@commandant, @resident_building_one).destroy?
  end

  test "destroy? denied for manager" do
    assert_not policy(@manager, @resident_building_one).destroy?
  end

  # check_ticket?
  test "check_ticket? allowed for admin" do
    assert policy(@admin, Dormitory::Resident).check_ticket?
  end

  test "check_ticket? allowed for commandant" do
    assert policy(@commandant, Dormitory::Resident).check_ticket?
  end

  test "check_ticket? denied for manager" do
    assert_not policy(@manager, Dormitory::Resident).check_ticket?
  end

  # Scope
  test "scope resolves to all kept for admin" do
    scope = Dormitory::ResidentPolicy::Scope.new(@admin, Dormitory::Resident)
    residents = scope.resolve
    assert_includes residents, @resident_building_one
    assert_includes residents, @resident_building_two
  end

  test "scope resolves to assigned buildings for commandant" do
    scope = Dormitory::ResidentPolicy::Scope.new(@commandant, Dormitory::Resident)
    residents = scope.resolve
    assert_includes residents, @resident_building_one
    assert_includes residents, @resident_building_two
    assert_not_includes residents, @resident_unassigned
  end

  test "scope resolves to none for manager" do
    scope = Dormitory::ResidentPolicy::Scope.new(@manager, Dormitory::Resident)
    assert_empty scope.resolve
  end
end
