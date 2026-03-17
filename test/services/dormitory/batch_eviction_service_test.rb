require "test_helper"

module Dormitory
  class BatchEvictionServiceTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      @commandant = users(:dormitory_commandant_user)
      Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
      @academic_year = dormitory_academic_years(:active_year_2025_2026)
      @building = dormitory_buildings(:building_one)
      @room_101 = dormitory_rooms(:room_101)
      @room_102 = dormitory_rooms(:room_102)
    end

    def settle_resident(name:, room:)
      resident = Resident.create!(
        last_name: name, first_name: "Тест", gender: :male,
        date_of_birth: 20.years.ago, student_ticket_number: "BATCH#{SecureRandom.hex(4)}"
      )
      acc = Accommodation.new(
        resident: resident, room: room,
        application_number: "B-#{SecureRandom.hex(3)}", contract_number: "C-#{SecureRandom.hex(3)}",
        start_date: Date.current, planned_end_date: Date.current + 1.year
      )
      acc.application_file.attach(
        io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )
      acc.payment_receipt.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
      acc.do_settle!
      [ resident, acc ]
    end

    test "successful mass eviction" do
      r1, _a1 = settle_resident(name: "Первый", room: @room_101)
      r2, _a2 = settle_resident(name: "Второй", room: @room_102)

      assert_difference -> { BatchOperation.count }, 1 do
        @result = BatchEvictionService.new(
          academic_year: @academic_year,
          building: @building,
          resident_ids: [ r1.id, r2.id ],
          eviction_reason: "graduation",
          performed_by: @admin
        ).call
      end

      assert_equal "completed", @result.status
      assert_equal 2, @result.total_count
      assert_equal 2, @result.success_count
      assert_equal 0, @result.error_count
      assert_equal "evicted", r1.reload.status
      assert_equal "evicted", r2.reload.status
    end

    test "validates at least one resident" do
      assert_raises(ArgumentError) do
        BatchEvictionService.new(
          academic_year: @academic_year, building: @building,
          resident_ids: [], eviction_reason: "graduation", performed_by: @admin
        ).call
      end
    end

    test "validates eviction reason" do
      r1, = settle_resident(name: "Третий", room: @room_101)
    end

    test "validates comment required for other" do
      r1, = settle_resident(name: "Четвёртый", room: @room_101)
      assert_raises(ArgumentError) do
        BatchEvictionService.new(
          academic_year: @academic_year, building: @building,
          resident_ids: [ r1.id ], eviction_reason: "other", performed_by: @admin
        ).call
      end
    end

    test "continues on individual errors" do
      r1, = settle_resident(name: "Пятый", room: @room_101)
      # r2 is not settled, so eviction will fail for it
      r2 = dormitory_residents(:resident_one_not_settled)

      result = BatchEvictionService.new(
        academic_year: @academic_year,
        building: @building,
        resident_ids: [ r1.id, r2.id ],
        eviction_reason: "graduation",
        performed_by: @admin
      ).call

      assert_equal "partial", result.status
      assert_equal 2, result.total_count
      assert_equal 1, result.success_count
      assert_equal 1, result.error_count
      assert_equal "evicted", r1.reload.status
    end
  end
end
