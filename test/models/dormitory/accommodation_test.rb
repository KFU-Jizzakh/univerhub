require "test_helper"

module Dormitory
  class AccommodationTest < ActiveSupport::TestCase
    setup do
      @resident = dormitory_residents(:resident_one_not_settled)
      @room = dormitory_rooms(:room_101)
      @building = dormitory_buildings(:building_one)
      @admin = users(:admin_user)
      Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    end

    def build_accommodation(overrides = {})
      attrs = {
        resident: @resident,
        room: @room,
        application_number: "З-001",
        contract_number: "Д-001",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year
      }.merge(overrides)
      Accommodation.new(attrs)
    end

    def attach_files(accommodation)
      accommodation.application_file.attach(
        io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
      )
      accommodation.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )
      accommodation.payment_receipt.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
    end

    test "valid accommodation with all fields" do
      acc = build_accommodation
      attach_files(acc)
      assert acc.valid?
    end

    test "requires resident" do
      acc = build_accommodation(resident: nil)
      attach_files(acc)
      assert_not acc.valid?
      assert acc.errors[:resident].any?
    end

    test "requires room" do
      acc = build_accommodation(room: nil)
      attach_files(acc)
      assert_not acc.valid?
      assert acc.errors[:room].any?
    end

    test "requires application_number" do
      acc = build_accommodation(application_number: "")
      assert_not acc.valid?
      assert acc.errors[:application_number].any?
    end

    test "requires contract_number" do
      acc = build_accommodation(contract_number: "")
      assert_not acc.valid?
      assert acc.errors[:contract_number].any?
    end

    test "requires start_date" do
      acc = build_accommodation(start_date: nil)
      assert_not acc.valid?
      assert acc.errors[:start_date].any?
    end

    test "comment length limit" do
      acc = build_accommodation(comment: "a" * 2001)
      assert_not acc.valid?
      assert acc.errors[:comment].any?
    end

    test "initial status is active" do
      acc = Accommodation.new
      assert_equal "active", acc.status
    end

    # --- Duration ---

    test "planned_duration_days returns days between start and planned end" do
      acc = build_accommodation(start_date: Date.new(2025, 9, 1), planned_end_date: Date.new(2026, 6, 1))
      assert_equal 273, acc.planned_duration_days
    end

    test "planned_duration_days returns nil without dates" do
      acc = Accommodation.new
      assert_nil acc.planned_duration_days
    end

    test "actual_duration_days returns nil when active" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      assert_nil acc.actual_duration_days
    end

    test "actual_duration_days returns days for completed accommodation" do
      acc = build_accommodation(start_date: Date.new(2025, 9, 1))
      attach_files(acc)
      acc.do_settle!
      acc.actual_end_date = Date.new(2025, 12, 31)
      acc.complete!

      assert_equal 121, acc.reload.actual_duration_days
    end

    test "overdue? returns true when active and past planned_end_date" do
      acc = build_accommodation(start_date: Date.current - 2, planned_end_date: Date.current - 1)
      attach_files(acc)
      acc.do_settle!

      assert acc.overdue?
    end

    test "overdue? returns false when active and planned_end_date is future" do
      acc = build_accommodation(start_date: Date.current - 1, planned_end_date: Date.current + 1)
      attach_files(acc)
      acc.do_settle!

      assert_not acc.overdue?
    end

    test "overdue? returns false when completed" do
      acc = build_accommodation(start_date: Date.current - 3, planned_end_date: Date.current - 1)
      attach_files(acc)
      acc.do_settle!
      acc.actual_end_date = Date.current
      acc.complete!

      assert_not acc.overdue?
    end

    # --- do_settle! ---

    test "do_settle! happy path — free room" do
      acc = build_accommodation
      attach_files(acc)

      assert_difference -> { OutboxEvent.count }, 2 do
        acc.do_settle!
      end

      assert acc.persisted?
      assert_equal "active", acc.status
      assert_equal "settled", @resident.reload.status
      assert_equal @room.id, @resident.current_room_id
      assert_equal 1, @room.reload.current_occupancy
      assert_includes %w[partially_occupied fully_occupied], @room.status
    end

    test "do_settle! creates OutboxEvent with correct action" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      event = OutboxEvent.find_by(action: "dormitory.accommodation.created")
      assert_equal "dormitory.accommodation.created", event.action
      assert_equal users(:admin_user), event.actor
      assert_equal acc, event.record
      assert_equal @resident.id, event.payload["resident_id"]
      assert_equal @room.id, event.payload["room_id"]
    end

    test "do_settle! blocks when resident already settled" do
      @resident.update!(status: :settled, current_room: @room)
      acc = build_accommodation
      attach_files(acc)

      assert_raises(ActiveRecord::RecordInvalid) { acc.do_settle! }
      assert_includes acc.errors[:resident], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.resident.already_settled")
    end

    test "do_settle! blocks on gender conflict" do
      room = dormitory_rooms(:room_102)
      room.update_column(:gender_restriction, :female)
      acc = build_accommodation(room: room)
      attach_files(acc)

      assert_raises(ActiveRecord::RecordInvalid) { acc.do_settle! }
      assert_includes acc.errors[:room], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.gender_conflict")
    end

    test "do_settle! allows when room has no gender restriction" do
      acc = build_accommodation
      @room.update_column(:gender_restriction, nil)
      attach_files(acc)

      acc.do_settle!
      assert acc.persisted?
    end

    test "do_settle! blocks when room is full" do
      room = dormitory_rooms(:room_102)
      room.update_columns(current_occupancy: 2, status: :fully_occupied)

      acc = build_accommodation(room: room)
      attach_files(acc)

      assert_raises(ActiveRecord::RecordInvalid) { acc.do_settle! }
      assert_includes acc.errors[:room], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.full")
    end

    test "do_settle! with force allows full room for admin" do
      room = dormitory_rooms(:room_102)
      room.update_columns(current_occupancy: 2, status: :fully_occupied)

      acc = build_accommodation(room: room)
      attach_files(acc)

      acc.do_settle!(force: true)

      assert acc.persisted?
      assert_equal "overcrowded", room.reload.status
    end

    test "do_settle! blocks without files" do
      acc = build_accommodation

      assert_raises(ActiveRecord::RecordInvalid) { acc.do_settle! }
      assert_includes acc.errors[:base], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.base.files_required")
    end

    test "do_settle! transitions room from free to partially_occupied" do
      acc = build_accommodation(room: dormitory_rooms(:room_101))
      attach_files(acc)
      acc.do_settle!

      assert_equal "partially_occupied", dormitory_rooms(:room_101).reload.status
    end

    test "do_settle! transitions room from free to fully_occupied when capacity reached" do
      room = dormitory_rooms(:room_102)
      room.update_columns(current_occupancy: 1, status: :partially_occupied)

      acc = build_accommodation(room: room)
      attach_files(acc)
      acc.do_settle!

      assert_equal "fully_occupied", room.reload.status
    end

    # --- File validations ---

    test "rejects invalid file format" do
      acc = build_accommodation
      acc.application_file.attach(
        io: StringIO.new("test"), filename: "app.txt", content_type: "text/plain"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )
      acc.payment_receipt.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )

      assert_not acc.valid?
      assert_includes acc.errors[:application_file], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.application_file.invalid_file_format")
    end

    test "rejects file too large" do
      acc = build_accommodation
      acc.application_file.attach(
        io: StringIO.new("x" * 11.megabytes), filename: "app.pdf", content_type: "application/pdf"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )
      acc.payment_receipt.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )

      assert_not acc.valid?
      assert_includes acc.errors[:application_file], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.application_file.file_too_large")
    end

    # --- AASM transitions ---

    test "can complete from active" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      acc.actual_end_date = Date.current
      acc.complete!
      assert_equal "completed", acc.reload.status
    end

    test "can cancel from active" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      acc.actual_end_date = Date.current
      acc.cancel!
      assert_equal "cancelled", acc.reload.status
    end

    # --- do_transfer! ---

    def create_settled_accommodation(room: @room)
      acc = build_accommodation(room: room)
      attach_files(acc)
      acc.do_settle!
      acc
    end

    def build_new_acc(room:, resident: @resident)
      acc = Accommodation.new(
        resident: resident,
        room: room,
        application_number: "З-ТР#{rand(1000)}",
        contract_number: "Д-ТР#{rand(1000)}",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year
      )
      attach_files(acc)
      acc
    end

    test "do_transfer! happy path — partially_occupied to free room" do
      old_acc = create_settled_accommodation(room: @room)
      target_room = dormitory_rooms(:room_102)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      assert_difference -> { OutboxEvent.count }, 4 do
        result = old_acc.do_transfer!(new_acc)

        assert result.persisted?
        assert_equal "active", result.status
      end

      assert_equal "completed", old_acc.reload.status
      assert_equal "transfer", old_acc.eviction_reason
      assert_equal Date.current, old_acc.actual_end_date

      assert_equal 0, @room.reload.current_occupancy
      assert_equal "free", @room.status

      assert_equal 1, target_room.reload.current_occupancy
      assert_includes %w[partially_occupied fully_occupied], target_room.status

      assert_equal "settled", @resident.reload.status
      assert_equal target_room.id, @resident.current_room_id
    end

    test "do_transfer! creates OutboxEvent with transferred action" do
      old_acc = create_settled_accommodation(room: @room)
      target_room = dormitory_rooms(:room_102)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      old_acc.do_transfer!(new_acc)

      event = OutboxEvent.where(record: old_acc, action: "dormitory.accommodation.transferred").first
      assert_equal "dormitory.accommodation.transferred", event.action
      assert_equal old_acc, event.record
      assert_equal @resident.id, event.payload["resident_id"]
      assert_equal @room.id, event.payload["from_room_id"]
      assert_equal target_room.id, event.payload["to_room_id"]
    end

    test "do_transfer! blocks when not active" do
      old_acc = create_settled_accommodation(room: @room)
      old_acc.actual_end_date = Date.current
      old_acc.complete!

      target_room = dormitory_rooms(:room_102)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_transfer!(new_acc) }
      assert_includes old_acc.errors[:status], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.status.not_active")
    end

    test "do_transfer! blocks on same room" do
      old_acc = create_settled_accommodation(room: @room)
      new_acc = build_new_acc(room: @room, resident: @resident)

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_transfer!(new_acc) }
      assert_includes old_acc.errors[:room], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.same_room")
    end

    test "do_transfer! blocks when target full" do
      old_acc = create_settled_accommodation(room: @room)
      target_room = dormitory_rooms(:room_102)
      target_room.update_columns(current_occupancy: 2, status: :fully_occupied)

      new_acc = build_new_acc(room: target_room, resident: @resident)

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_transfer!(new_acc) }
      assert_includes old_acc.errors[:room], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.full")
    end

    test "do_transfer! blocks on gender conflict" do
      old_acc = create_settled_accommodation(room: @room)
      target_room = dormitory_rooms(:room_102)
      target_room.update_column(:gender_restriction, :female)

      new_acc = build_new_acc(room: target_room, resident: @resident)

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_transfer!(new_acc) }
      assert_includes old_acc.errors[:room], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.gender_conflict")
    end

    test "do_transfer! blocks without files on new accommodation" do
      old_acc = create_settled_accommodation(room: @room)
      target_room = dormitory_rooms(:room_102)
      new_acc = Accommodation.new(
        resident: @resident, room: target_room,
        application_number: "З-ТР", contract_number: "Д-ТР",
        start_date: Date.current
      )

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_transfer!(new_acc) }
    end

    test "do_transfer! works for temporarily absent resident" do
      @resident.update!(status: :settled, current_room: @room)
      old_acc = Accommodation.create!(
        resident: @resident, room: @room,
        application_number: "З-ТА", contract_number: "Д-ТА",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )
      @resident.update!(status: :temporarily_absent)

      target_room = dormitory_rooms(:room_102)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      old_acc.do_transfer!(new_acc)

      assert_equal "settled", @resident.reload.status
      assert_equal target_room.id, @resident.current_room_id
    end

    test "do_transfer! from fully_occupied recalculates to partially_occupied" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 2, status: :fully_occupied)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-ФО", contract_number: "Д-ФО",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      target_room = dormitory_rooms(:room_101)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      old_acc.do_transfer!(new_acc)

      assert_equal 1, room_102.reload.current_occupancy
      assert_equal "partially_occupied", room_102.status
    end

    test "do_transfer! from overcrowded normalizes" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 3, capacity: 2, status: :overcrowded)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-ОВ", contract_number: "Д-ОВ",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      target_room = dormitory_rooms(:room_101)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      old_acc.do_transfer!(new_acc)

      assert_equal 2, room_102.reload.current_occupancy
      assert_equal "fully_occupied", room_102.status
    end

    # --- do_evict! ---

    def create_settled_for_eviction(room: @room, occupancy: 1, status: :partially_occupied)
      room.update_columns(current_occupancy: occupancy, status: status)
      @resident.update!(status: :settled, current_room: room)
      acc = Accommodation.create!(
        resident: @resident, room: room,
        application_number: "З-EV", contract_number: "Д-EV",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )
      acc
    end

    test "do_evict! happy path — settled resident" do
      old_acc = create_settled_for_eviction(room: @room, occupancy: 1, status: :partially_occupied)

      assert_difference -> { OutboxEvent.count }, 2 do
        old_acc.do_evict!(eviction_reason: "graduation")
      end

      assert_equal "completed", old_acc.reload.status
      assert_equal "graduation", old_acc.eviction_reason
      assert_equal Date.current, old_acc.actual_end_date

      assert_equal 0, @room.reload.current_occupancy
      assert_equal "free", @room.status

      assert_equal "evicted", @resident.reload.status
      assert_nil @resident.current_room_id
    end

    test "do_evict! works for temporarily absent resident" do
      old_acc = create_settled_for_eviction(room: @room, occupancy: 1, status: :partially_occupied)
      @resident.update!(status: :temporarily_absent)

      old_acc.do_evict!(eviction_reason: "voluntary")

      assert_equal "completed", old_acc.reload.status
      assert_equal "evicted", @resident.reload.status
      assert_nil @resident.current_room_id
    end

    test "do_evict! creates OutboxEvent with evicted action" do
      old_acc = create_settled_for_eviction
      old_acc.do_evict!(eviction_reason: "expulsion")

      event = OutboxEvent.find_by(action: "dormitory.accommodation.evicted")
      assert_equal "dormitory.accommodation.evicted", event.action
      assert_equal users(:admin_user), event.actor
      assert_equal old_acc, event.record
      assert_equal @resident.id, event.payload["resident_id"]
      assert_equal @room.id, event.payload["room_id"]
      assert_equal "expulsion", event.payload["eviction_reason"]
    end

    test "do_evict! updates comment" do
      old_acc = create_settled_for_eviction
      old_acc.do_evict!(eviction_reason: "voluntary", comment: "Уехал по личным причинам")

      assert_equal "Уехал по личным причинам", old_acc.reload.comment
    end

    test "do_evict! from partially_occupied with last resident → free" do
      old_acc = create_settled_for_eviction(room: @room, occupancy: 1, status: :partially_occupied)
      old_acc.do_evict!(eviction_reason: "graduation")

      assert_equal 0, @room.reload.current_occupancy
      assert_equal "free", @room.status
    end

    test "do_evict! from fully_occupied → partially_occupied" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 2, capacity: 2, status: :fully_occupied)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-FO-EV", contract_number: "Д-FO-EV",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      old_acc.do_evict!(eviction_reason: "graduation")

      assert_equal 1, room_102.reload.current_occupancy
      assert_equal "partially_occupied", room_102.status
    end

    test "do_evict! from fully_occupied with last resident → free" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 1, capacity: 1, status: :fully_occupied)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-FO2-EV", contract_number: "Д-FO2-EV",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      old_acc.do_evict!(eviction_reason: "graduation")

      assert_equal 0, room_102.reload.current_occupancy
      assert_equal "free", room_102.status
    end

    test "do_evict! from overcrowded → normalize to fully_occupied" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 3, capacity: 2, status: :overcrowded)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-OV-EV", contract_number: "Д-OV-EV",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      old_acc.do_evict!(eviction_reason: "graduation")

      assert_equal 2, room_102.reload.current_occupancy
      assert_equal "fully_occupied", room_102.status
    end

    test "do_evict! from overcrowded → partially_occupied" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 3, capacity: 4, status: :overcrowded)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-OV2-EV", contract_number: "Д-OV2-EV",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      old_acc.do_evict!(eviction_reason: "graduation")

      assert_equal 2, room_102.reload.current_occupancy
      assert_equal 4, room_102.capacity
      assert_equal "partially_occupied", room_102.status
    end

    test "do_evict! from overcrowded → free when occupancy drops to zero" do
      room_102 = dormitory_rooms(:room_102)
      room_102.update_columns(current_occupancy: 1, capacity: 2, status: :overcrowded)
      @resident.update!(status: :settled, current_room: room_102)
      old_acc = Accommodation.create!(
        resident: @resident, room: room_102,
        application_number: "З-OV3-EV", contract_number: "Д-OV3-EV",
        start_date: Date.current, planned_end_date: Date.current + 1.year,
        academic_year: dormitory_academic_years(:active_year_2025_2026)
      )

      old_acc.do_evict!(eviction_reason: "graduation")

      assert_equal 0, room_102.reload.current_occupancy
      assert_equal "free", room_102.status
    end

    test "do_evict! blocks when accommodation not active" do
      old_acc = create_settled_for_eviction
      old_acc.actual_end_date = Date.current
      old_acc.complete!

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_evict!(eviction_reason: "graduation") }
      assert_includes old_acc.errors[:status], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.status.not_active")
    end

    test "do_evict! blocks when resident not settled" do
      old_acc = create_settled_for_eviction
      @resident.update!(status: :not_settled, current_room_id: nil)
      old_acc.resident.reload

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_evict!(eviction_reason: "graduation") }
      assert_includes old_acc.errors[:resident], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.resident.not_settled")
    end

    test "do_evict! blocks with invalid reason" do
      old_acc = create_settled_for_eviction

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_evict!(eviction_reason: "invalid") }
      assert_includes old_acc.errors[:eviction_reason], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.eviction_reason.invalid")
    end

    test "do_evict! blocks when reason is other without comment" do
      old_acc = create_settled_for_eviction

      assert_raises(ActiveRecord::RecordInvalid) { old_acc.do_evict!(eviction_reason: "other", comment: nil) }
      assert_includes old_acc.errors[:comment], I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.comment.required_for_other")
    end

    test "do_evict! allows other reason with comment" do
      old_acc = create_settled_for_eviction
      old_acc.do_evict!(eviction_reason: "other", comment: "Личные обстоятельства")

      assert_equal "completed", old_acc.reload.status
      assert_equal "other", old_acc.eviction_reason
      assert_equal "Личные обстоятельства", old_acc.comment
    end

    # --- Room status tracking ---

    test "do_settle! tracks room status change" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      room_event = OutboxEvent.find_by(
        record_type: "Dormitory::Room",
        action: "dormitory.room.occupy"
      )
      assert room_event, "Expected dormitory.room.occupy OutboxEvent"
      assert_equal @room, room_event.record
      assert_equal "free", room_event.payload["from"]
      assert_equal @room.reload.status, room_event.payload["to"]
    end

    test "do_evict! tracks room status change" do
      old_acc = create_settled_for_eviction(room: @room, occupancy: 1, status: :partially_occupied)
      old_acc.do_evict!(eviction_reason: "graduation")

      room_event = OutboxEvent.find_by(
        record_type: "Dormitory::Room",
        action: "dormitory.room.evict_all"
      )
      assert room_event, "Expected dormitory.room.evict_all OutboxEvent"
      assert_equal @room, room_event.record
      assert_equal "partially_occupied", room_event.payload["from"]
      assert_equal "free", room_event.payload["to"]
    end

    test "do_transfer! tracks room status changes for both rooms" do
      old_acc = create_settled_accommodation(room: @room)
      target_room = dormitory_rooms(:room_102)
      new_acc = build_new_acc(room: target_room, resident: @resident)

      old_acc.do_transfer!(new_acc)

      old_room_event = OutboxEvent.find_by(
        record_type: "Dormitory::Room",
        record_id: @room.id,
        action: "dormitory.room.evict_all"
      )
      assert old_room_event, "Expected room evict_all for old room"
      assert_equal "partially_occupied", old_room_event.payload["from"]
      assert_equal "free", old_room_event.payload["to"]

      new_room_event = OutboxEvent.find_by(
        record_type: "Dormitory::Room",
        record_id: target_room.id,
        action: "dormitory.room.occupy"
      )
      assert new_room_event, "Expected room occupy for target room"
      assert_equal "free", new_room_event.payload["from"]
      assert_equal target_room.reload.status, new_room_event.payload["to"]
    end

    # --- SPEC-DORM-09: Payment receipts & amount tracking ---

    def attach_receipt_to(receipt)
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
    end

    def create_receipt_for(accommodation, amount:, paid_at: Date.current)
      receipt = accommodation.receipts.build(amount: amount, paid_at: paid_at)
      attach_receipt_to(receipt)
      receipt.save!
      receipt
    end

    test "required_amount defaults to zero" do
      acc = build_accommodation
      assert_equal 0, acc.required_amount
    end

    test "required_amount must be non-negative" do
      acc = build_accommodation(required_amount: -100)
      assert_not acc.valid?
      assert acc.errors[:required_amount].any?
    end

    test "total_paid sums receipt amounts" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      r1 = acc.receipts.build(amount: 3000, paid_at: Date.current)
      attach_receipt_to(r1)
      r1.save!
      r2 = acc.receipts.build(amount: 2000, paid_at: Date.current - 1)
      attach_receipt_to(r2)
      r2.save!

      assert_equal 5000, acc.total_paid
    end

    test "total_paid is zero when no receipts" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      assert_equal 0, acc.total_paid
    end

    test "total_paid excludes discarded receipts" do
      acc = build_accommodation
      attach_files(acc)
      acc.do_settle!

      r1 = create_receipt_for(acc, amount: 3000)
      r2 = create_receipt_for(acc, amount: 2000, paid_at: Date.current - 1)
      r2.discard!

      assert_equal 3000, acc.total_paid
    end

    test "balance is negative when underpaid" do
      acc = build_accommodation(required_amount: 10000)
      attach_files(acc)
      acc.do_settle!

      r = create_receipt_for(acc, amount: 6000)

      assert_equal (-4000), acc.balance
    end

    test "balance is positive when overpaid" do
      acc = build_accommodation(required_amount: 10000)
      attach_files(acc)
      acc.do_settle!

      r = create_receipt_for(acc, amount: 12000)

      assert_equal 2000, acc.balance
    end

    test "balance is zero when exactly paid" do
      acc = build_accommodation(required_amount: 10000)
      attach_files(acc)
      acc.do_settle!

      r = create_receipt_for(acc, amount: 10000)

      assert_equal 0, acc.balance
    end

    test "has_payment_file? true with receipt attachment" do
      acc = build_accommodation
      acc.application_file.attach(
        io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )

      receipt = acc.receipts.build(amount: 5000, paid_at: Date.current)
      attach_receipt_to(receipt)

      assert acc.has_payment_file?
    end

    test "has_payment_file? true with legacy payment_receipt" do
      acc = build_accommodation
      attach_files(acc)

      assert acc.has_payment_file?
    end

    test "has_payment_file? false without any payment document" do
      acc = build_accommodation
      acc.application_file.attach(
        io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )

      assert_not acc.has_payment_file?
    end

    test "do_settle! succeeds with nested receipt" do
      acc = build_accommodation(required_amount: 12000)
      acc.application_file.attach(
        io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )

      receipt = acc.receipts.build(amount: 12000, paid_at: Date.current)
      attach_receipt_to(receipt)

      assert_difference -> { OutboxEvent.count }, 2 do
        acc.do_settle!
      end
      assert acc.persisted?
      assert_equal "active", acc.status
      assert_equal 12000, acc.total_paid
      assert_equal 0, acc.balance
    end

    test "do_settle! blocks without payment file" do
      acc = build_accommodation
      acc.application_file.attach(
        io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
      )
      acc.contract_file.attach(
        io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
      )

      assert_raises(ActiveRecord::RecordInvalid) { acc.do_settle! }
      assert_includes acc.errors[:base],
        I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.base.files_required")
    end

    test "do_settle! with legacy payment_receipt still works" do
      acc = build_accommodation
      attach_files(acc)

      assert acc.do_settle!
      assert acc.persisted?
    end

    test "payment_overdue? true when balance negative and active" do
      acc = build_accommodation(required_amount: 10000)
      attach_files(acc)
      acc.do_settle!

      r = create_receipt_for(acc, amount: 6000)

      assert acc.payment_overdue?
    end

    test "payment_overdue? false when balance non-negative" do
      acc = build_accommodation(required_amount: 10000)
      attach_files(acc)
      acc.do_settle!

      r = create_receipt_for(acc, amount: 10000)

      assert_not acc.payment_overdue?
    end

    test "payment_overdue? false when accommodation completed" do
      acc = build_accommodation(required_amount: 10000)
      attach_files(acc)
      acc.do_settle!
      acc.update_columns(actual_end_date: Date.current, status: "completed")

      assert_not acc.payment_overdue?
    end
  end
end
