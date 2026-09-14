require "test_helper"

module Dormitory
  class TransferReceiptsBackfillServiceTest < ActiveSupport::TestCase
    setup do
      @room_101 = dormitory_rooms(:room_101)
      @room_102 = dormitory_rooms(:room_102)
    end

    def create_resident
      Resident.create!(
        last_name: "Бэкфилл#{("а".."я").to_a.sample(3).join}", first_name: "Тест", gender: :male,
        date_of_birth: 20.years.ago, student_ticket_number: "BF#{SecureRandom.hex(4)}"
      )
    end

    def create_acc(resident:, room:, start_date:, status: :active, eviction_reason: nil,
                   actual_end_date: nil, required_amount: 0, discarded: false)
      acc = Accommodation.new(
        resident: resident, room: room,
        application_number: "З-BF#{SecureRandom.hex(3)}", contract_number: "Д-BF#{SecureRandom.hex(3)}",
        start_date: start_date, planned_end_date: start_date + 1.year,
        required_amount: required_amount
      )
      if status == :completed
        acc.actual_end_date = actual_end_date || Date.current - 3.days
        acc.eviction_reason = eviction_reason
        acc.complete!
      else
        acc.save!
      end
      acc.discard! if discarded
      acc
    end

    def create_receipt(acc, amount: 5000)
      receipt = acc.receipts.build(amount: amount, paid_at: Date.current)
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
      receipt.save!
      receipt
    end

    def create_origin(resident, eviction_reason: "transfer", required_amount: 12000, discarded: false, actual_end_date: nil)
      create_acc(resident: resident, room: @room_101, start_date: Date.current - 100.days,
                 status: :completed, eviction_reason: eviction_reason,
                 actual_end_date: actual_end_date || Date.current - 3.days,
                 required_amount: required_amount, discarded: discarded)
    end

    def create_successor(resident, start_date:, required_amount: 0)
      create_acc(resident: resident, room: @room_102, start_date: start_date,
                 required_amount: required_amount)
    end

    test "moves receipts and copies required_amount to the successor" do
      resident = create_resident
      old_acc = create_origin(resident)
      successor = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 1, stats.pairs_processed
      assert_equal 1, stats.receipts_moved
      assert_equal 1, stats.amounts_copied
      assert_equal 0, stats.skipped_without_successor
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: successor.id).count
      assert_equal 12000, successor.reload.required_amount
    end

    test "keeps explicitly set required_amount on the successor" do
      resident = create_resident
      old_acc = create_origin(resident)
      successor = create_successor(resident, start_date: Date.current - 3.days, required_amount: 9000)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 1, stats.receipts_moved
      assert_equal 0, stats.amounts_copied
      assert_equal 9000, successor.reload.required_amount
    end

    test "processes repair origins" do
      resident = create_resident
      old_acc = create_origin(resident, eviction_reason: "repair")
      successor = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 1, stats.pairs_processed
      assert_equal 1, stats.receipts_moved
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: successor.id).count
    end

    test "processes discarded origins" do
      resident = create_resident
      old_acc = create_origin(resident, discarded: true)
      successor = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 1, stats.pairs_processed
      assert_equal 1, stats.receipts_moved
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: successor.id).count
    end

    test "ignores completed accommodations with non-transfer eviction reasons" do
      resident = create_resident
      old_acc = create_origin(resident, eviction_reason: "graduation", required_amount: 0)
      successor = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 0, stats.pairs_processed
      assert_equal 0, stats.receipts_moved
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: successor.id).count
    end

    test "skips transfer origins without a successor" do
      resident = create_resident
      old_acc = create_origin(resident)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 0, stats.pairs_processed
      assert_equal 1, stats.skipped_without_successor
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
    end

    test "skips origins whose successor starts on a different day" do
      resident = create_resident
      old_acc = create_origin(resident)
      successor = create_successor(resident, start_date: Date.current - 2.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 0, stats.pairs_processed
      assert_equal 1, stats.skipped_without_successor
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: successor.id).count
    end

    test "picks the earliest successor by id on same-day ties" do
      resident = create_resident
      old_acc = create_origin(resident)
      first = create_acc(resident: resident, room: @room_102, start_date: Date.current - 3.days,
                         status: :completed, actual_end_date: Date.current - 2.days)
      second = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new.call

      assert_equal 1, stats.pairs_processed
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: first.id).count
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: second.id).count
    end

    test "records an aggregate audit event with updated_at bumped" do
      resident = create_resident
      old_acc = create_origin(resident)
      successor = create_successor(resident, start_date: Date.current - 3.days)
      receipt = create_receipt(old_acc)

      TransferReceiptsBackfillService.new.call

      event = OutboxEvent.where(record: old_acc, action: "dormitory.receipts.transferred").first
      assert_equal successor.id, event.payload["to_accommodation_id"]
      assert_equal 1, event.payload["count"]
      assert_equal "backfill", event.payload["via"]
      assert receipt.reload.updated_at > receipt.created_at
    end

    test "dry run makes no changes" do
      resident = create_resident
      old_acc = create_origin(resident)
      successor = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      stats = TransferReceiptsBackfillService.new(dry_run: true).call

      assert_equal 1, stats.pairs_processed
      assert_equal 1, stats.receipts_moved
      assert_equal 1, stats.amounts_copied
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: old_acc.id).count
      assert_equal 0, Receipt.with_discarded.where(accommodation_id: successor.id).count
      assert_equal 0, successor.reload.required_amount
    end

    test "is idempotent" do
      resident = create_resident
      old_acc = create_origin(resident)
      successor = create_successor(resident, start_date: Date.current - 3.days)
      create_receipt(old_acc)

      first = TransferReceiptsBackfillService.new.call
      second = TransferReceiptsBackfillService.new.call

      assert_equal 1, first.receipts_moved
      assert_equal 0, second.receipts_moved
      assert_equal 0, second.pairs_processed
      assert_equal 1, Receipt.with_discarded.where(accommodation_id: successor.id).count
    end
  end
end
