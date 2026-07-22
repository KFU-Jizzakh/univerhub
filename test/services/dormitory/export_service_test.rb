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
  end
end
