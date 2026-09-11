require "test_helper"

module Dormitory
  class ExportServiceTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
      @building = dormitory_buildings(:building_one)
      @room_101 = dormitory_rooms(:room_101)
    end

    test "settled_residents_csv returns CSV with headers" do
      csv = ExportService.settled_residents_csv(
        Dormitory::Resident.all, building_id: @building.id
      )
      assert csv.start_with?("\uFEFF")
      assert csv.include?(";")
    end

    test "free_slots_csv returns CSV with headers" do
      csv = ExportService.free_slots_csv(Dormitory::Room.all)
      assert csv.start_with?("\uFEFF")
      assert csv.include?(";")
    end

    test "history_csv returns CSV with headers" do
      csv = ExportService.history_csv(Dormitory::Accommodation.all)
      assert csv.start_with?("\uFEFF")
      assert csv.include?(";")
    end

    test "occupancy_stats_csv returns CSV with headers" do
      csv = ExportService.occupancy_stats_csv(Dormitory::Building.all)
      assert csv.start_with?("\uFEFF")
      assert csv.include?(";")
    end

    test "settled_residents_csv includes resident data" do
      resident = dormitory_residents(:resident_two_settled)
      csv = ExportService.settled_residents_csv(Dormitory::Resident.all)
      assert csv.include?(resident.last_name)
    end

    test "history_csv filters by building" do
      csv_all = ExportService.history_csv(Dormitory::Accommodation.all)
      csv_filtered = ExportService.history_csv(Dormitory::Accommodation.all, building_id: @building.id)
      assert csv_all.start_with?("\uFEFF")
      assert csv_filtered.start_with?("\uFEFF")
    end

    test "occupancy_stats_csv includes subtotal rows" do
      csv = ExportService.occupancy_stats_csv(Dormitory::Building.all)
      assert csv.include?("Итого")
    end

    # --- SPEC-DORM-09: Payment columns in exports ---

    test "settled_residents_csv includes payment column headers" do
      csv = ExportService.settled_residents_csv(Dormitory::Resident.all, building_id: @building.id)
      assert csv.include?("Сумма к оплате")
      assert csv.include?("Уплачено")
      assert csv.include?("Остаток")
    end

    test "history_csv includes payment column headers" do
      csv = ExportService.history_csv(Dormitory::Accommodation.all)
      assert csv.include?("Сумма к оплате")
      assert csv.include?("Уплачено")
      assert csv.include?("Остаток")
    end

    test "settled_residents_csv payment values are formatted with two decimals" do
      resident = dormitory_residents(:resident_two_settled)
      csv = ExportService.settled_residents_csv(Dormitory::Resident.all)
      assert csv.include?("0.00")
    end

    test "history_csv payment values are formatted with two decimals" do
      csv = ExportService.history_csv(Dormitory::Accommodation.all)
      assert csv.include?("0.00")
    end

    # --- SPEC-DORM-09: Debtors CSV ---

    def attach_receipt(receipt)
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
    end

    test "debtors_csv includes debtors with payment and overdue columns" do
      debtor = dormitory_accommodations(:active_accommodation)
      debtor.update_columns(required_amount: 12000, planned_end_date: Date.current - 1.day)
      receipt = debtor.receipts.build(amount: 8000, paid_at: Date.current)
      attach_receipt(receipt)
      receipt.save!

      csv = ExportService.debtors_csv(Dormitory::Accommodation.all)

      assert csv.start_with?("\uFEFF")
      assert_includes csv, "Долг"
      assert_includes csv, "Просрочено"
      assert_includes csv, debtor.resident.full_name
      assert_includes csv, "4000.00"
      assert_includes csv, "Да"
    end

    test "debtors_csv excludes fully paid accommodations" do
      paid = dormitory_accommodations(:active_accommodation)
      paid.update!(required_amount: 10000)
      receipt = paid.receipts.build(amount: 10000, paid_at: Date.current)
      attach_receipt(receipt)
      receipt.save!

      csv = ExportService.debtors_csv(Dormitory::Accommodation.all)

      assert_not_includes csv, paid.resident.full_name
    end

    test "debtors_csv avoids per-row receipt sum queries" do
      debtor = dormitory_accommodations(:active_accommodation)
      debtor.update!(required_amount: 20000)
      receipt_one = debtor.receipts.build(amount: 5000, paid_at: Date.current)
      attach_receipt(receipt_one)
      receipt_one.save!
      receipt_two = debtor.receipts.build(amount: 3000, paid_at: Date.current)
      attach_receipt(receipt_two)
      receipt_two.save!

      assert_no_queries_match(/SUM\("dormitory_receipts"/i) do
        csv = ExportService.debtors_csv(Dormitory::Accommodation.all)
        assert_includes csv, "12000.00"
      end
    end
  end
end
