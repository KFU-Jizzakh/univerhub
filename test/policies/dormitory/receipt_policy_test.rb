require "test_helper"

module Dormitory
  class ReceiptPolicyTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      @dormitory_admin = users(:dormitory_admin_user)
      @commandant = users(:dormitory_commandant_user)
      @plain_user = users(:reporter_user)

      @building_one = dormitory_buildings(:building_one)
      @building_two = dormitory_buildings(:building_two)
      @room_101 = dormitory_rooms(:room_101)
      @room_101_b2 = dormitory_rooms(:room_101_building_two)

      @accommodation = dormitory_accommodations(:active_accommodation)
      @accommodation.update!(status: :active)
    end

    def build_receipt_for(accommodation)
      receipt = Receipt.new(accommodation: accommodation, amount: 100, paid_at: Date.current)
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
      receipt
    end

    def create_receipt_for(accommodation)
      receipt = build_receipt_for(accommodation)
      receipt.do_create!
      receipt
    end

    def policy(user, record)
      ReceiptPolicy.new(user, record)
    end

    # --- Admin ---

    test "admin can new" do
      receipt = build_receipt_for(@accommodation)
      assert policy(@admin, receipt).new?
    end

    test "admin can create" do
      receipt = build_receipt_for(@accommodation)
      assert policy(@admin, receipt).create?
    end

    test "admin can edit" do
      receipt = create_receipt_for(@accommodation)
      assert policy(@admin, receipt).edit?
    end

    test "admin can update" do
      receipt = create_receipt_for(@accommodation)
      assert policy(@admin, receipt).update?
    end

    test "admin can destroy" do
      receipt = create_receipt_for(@accommodation)
      assert policy(@admin, receipt).destroy?
    end

    # --- Dormitory Admin ---

    test "dormitory admin can new" do
      receipt = build_receipt_for(@accommodation)
      assert policy(@dormitory_admin, receipt).new?
    end

    test "dormitory admin can create" do
      receipt = build_receipt_for(@accommodation)
      assert policy(@dormitory_admin, receipt).create?
    end

    # --- Commandant (assigned building) ---

    test "commandant can new for assigned building" do
      receipt = build_receipt_for(@accommodation)
      assert policy(@commandant, receipt).new?
    end

    test "commandant can create for assigned building" do
      receipt = build_receipt_for(@accommodation)
      assert policy(@commandant, receipt).create?
    end

    test "commandant can edit for assigned building" do
      receipt = create_receipt_for(@accommodation)
      assert policy(@commandant, receipt).edit?
    end

    test "commandant can destroy for assigned building" do
      receipt = create_receipt_for(@accommodation)
      assert policy(@commandant, receipt).destroy?
    end

    # --- Commandant (unassigned building) ---

    def commandant_reassigned_to(other_building)
      Dormitory::CommandantBuilding.active.where(user: @commandant).destroy_all
      Dormitory::CommandantBuilding.create!(user: @commandant, building: other_building)
    end

    test "commandant cannot new for unassigned building" do
      commandant_reassigned_to(@building_two)
      receipt = build_receipt_for(@accommodation)
      assert_not policy(@commandant, receipt).new?
    end

    test "commandant cannot create for unassigned building" do
      commandant_reassigned_to(@building_two)
      receipt = build_receipt_for(@accommodation)
      assert_not policy(@commandant, receipt).create?
    end

    test "commandant cannot edit for unassigned building" do
      receipt = create_receipt_for(@accommodation)
      commandant_reassigned_to(@building_two)
      assert_not policy(@commandant, receipt).edit?
    end

    test "commandant cannot destroy for unassigned building" do
      receipt = create_receipt_for(@accommodation)
      commandant_reassigned_to(@building_two)
      assert_not policy(@commandant, receipt).destroy?
    end

    # --- Plain user ---

    test "plain user cannot new" do
      receipt = build_receipt_for(@accommodation)
      assert_not policy(@plain_user, receipt).new?
    end

    test "plain user cannot create" do
      receipt = build_receipt_for(@accommodation)
      assert_not policy(@plain_user, receipt).create?
    end

    test "plain user cannot edit" do
      receipt = create_receipt_for(@accommodation)
      assert_not policy(@plain_user, receipt).edit?
    end

    test "plain user cannot destroy" do
      receipt = create_receipt_for(@accommodation)
      assert_not policy(@plain_user, receipt).destroy?
    end

    # --- Scope ---

    test "admin scope includes all kept receipts" do
      r1 = create_receipt_for(@accommodation)
      acc_b2 = Accommodation.create!(
        resident: dormitory_residents(:resident_four_other_building),
        room: @room_101_b2,
        application_number: "B2-001",
        contract_number: "B2-001",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year
      )
      r2 = create_receipt_for(acc_b2)

      scope = ReceiptPolicy::Scope.new(@admin, Receipt.all).resolve
      assert_includes scope, r1
      assert_includes scope, r2
    end

    test "commandant scope includes only assigned building receipts" do
      commandant_reassigned_to(@building_one)
      r1 = create_receipt_for(@accommodation)
      acc_b2 = Accommodation.create!(
        resident: dormitory_residents(:resident_four_other_building),
        room: @room_101_b2,
        application_number: "B2-003",
        contract_number: "B2-003",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year
      )
      r2 = create_receipt_for(acc_b2)

      scope = ReceiptPolicy::Scope.new(@commandant, Receipt.all).resolve
      assert_includes scope, r1
      assert_not_includes scope, r2
    end

    test "scope excludes discarded receipts" do
      r1 = create_receipt_for(@accommodation)
      r2 = create_receipt_for(@accommodation)
      r2.discard!

      scope = ReceiptPolicy::Scope.new(@admin, Receipt.all).resolve
      assert_includes scope, r1
      assert_not_includes scope, r2
    end
  end
end
