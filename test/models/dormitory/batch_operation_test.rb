require "test_helper"

module Dormitory
  class BatchOperationTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      @academic_year = dormitory_academic_years(:active_year_2025_2026)
      @building = dormitory_buildings(:building_one)
    end

    test "creates batch operation" do
      op = BatchOperation.new(
        academic_year: @academic_year,
        building: @building,
        operation_type: "mass_eviction",
        performed_by: @admin
      )
      assert op.valid?
      op.save!
      assert_equal "pending", op.status
    end

    test "requires operation_type" do
      op = BatchOperation.new(
        academic_year: @academic_year, building: @building
      )
      assert_not op.valid?
      assert op.errors[:operation_type].any?
    end

    test "validates operation_type inclusion" do
      op = BatchOperation.new(
        academic_year: @academic_year, building: @building, operation_type: "invalid"
      )
      assert_not op.valid?
    end

    test "do_start! sets initial counts and status" do
      op = BatchOperation.create!(
        academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
      )
      op.do_start!(5)
      assert_equal "pending", op.status
      assert_equal 5, op.total_count
      assert_equal 0, op.success_count
      assert_equal 0, op.error_count
      assert_not_nil op.started_at
    end

    test "record_success! increments count" do
      op = BatchOperation.create!(
        academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
      )
      op.do_start!(2)
      op.record_success!
      assert_equal 1, op.success_count
      op.record_success!
      assert_equal 2, op.success_count
    end

    test "record_error! creates error record and increments count" do
      op = BatchOperation.create!(
        academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
      )
      op.do_start!(1)
      resident = dormitory_residents(:resident_one_not_settled)

      assert_difference -> { BatchOperationError.count }, 1 do
        op.record_error!(resident: resident, accommodation: nil, error_message: "Test error")
      end
      assert_equal 1, op.error_count

      error = op.batch_operation_errors.last
      assert_equal resident, error.resident
      assert_equal "Test error", error.error_message
    end

    test "do_complete! sets completed_at and status" do
      op = BatchOperation.create!(
        academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
      )
      op.do_start!(1)
      op.record_success!
      op.do_complete!
      assert_equal "completed", op.status
      assert_not_nil op.completed_at
    end

    test "pending? and completed? predicates" do
      op = BatchOperation.create!(
        academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
      )
      assert op.pending?
      op.do_start!(1)
      op.record_success!
      op.do_complete!
      assert op.completed?
    end

    test "partial? predicate" do
      op = BatchOperation.create!(
        academic_year: @academic_year, building: @building, operation_type: "mass_eviction"
      )
      op.do_start!(2)
      op.record_success!
      op.record_error!(resident: nil, accommodation: nil, error_message: "fail")
      op.do_complete!(status: "partial")
      assert op.partial?
      assert_not op.completed?
    end
  end
end
