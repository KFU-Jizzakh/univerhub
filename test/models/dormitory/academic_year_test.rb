require "test_helper"

module Dormitory
  class AcademicYearTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_user)
      Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
      @active_year = dormitory_academic_years(:active_year_2025_2026)
      @pending_year = dormitory_academic_years(:pending_year_2026_2027)
      # Deactivate the fixture active year so tests can activate new ones
      @active_year.update_columns(status: :closed, closed_at: Time.current)
    end

    teardown do
      # Restore fixture active year status
      @active_year.reload.update_columns(status: :active, closed_at: nil) rescue nil
    end

    test "valid academic year" do
      year = AcademicYear.new(
        name: "2027/2028", start_date: Date.new(2027, 9, 1), end_date: Date.new(2028, 8, 31)
      )
      assert year.valid?
    end

    test "requires name" do
      year = AcademicYear.new(start_date: Date.current, end_date: Date.current + 1.year)
      assert_not year.valid?
      assert year.errors[:name].any?
    end

    test "requires unique name" do
      year = AcademicYear.new(
        name: @active_year.name, start_date: Date.current, end_date: Date.current + 1.year
      )
      assert_not year.valid?
      assert year.errors[:name].any?
    end

    test "requires start_date before end_date" do
      year = AcademicYear.new(
        name: "Test", start_date: Date.new(2027, 9, 1), end_date: Date.new(2026, 9, 1)
      )
      assert_not year.valid?
      assert year.errors[:end_date].any?
    end

    test "initial status is pending" do
      year = AcademicYear.new
      assert_equal "pending", year.status
    end

    test "do_create! creates audit event" do
      year = AcademicYear.new(
        name: "2027/2028", start_date: Date.new(2027, 9, 1), end_date: Date.new(2028, 8, 31)
      )
      assert_difference -> { OutboxEvent.count }, 1 do
        year.do_create!
      end
      assert year.persisted?
      assert_equal "pending", year.status
    end

    test "do_activate! transitions pending to active" do
      @pending_year.update_columns(status: :pending)
      assert_difference -> { OutboxEvent.count }, 1 do
        @pending_year.do_activate!
      end
      assert @pending_year.active?
    end

    test "do_activate! fails when another active year exists" do
      # Create an active year first
      existing = AcademicYear.create!(
        name: "ExistingActive", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      another = AcademicYear.create!(
        name: "Another", start_date: Date.current, end_date: Date.current + 1.year
      )
      assert_raises(ActiveRecord::RecordInvalid) { another.do_activate! }
      assert_includes another.errors[:base],
                      I18n.t("activerecord.errors.models.dormitory/academic_year.attributes.base.already_active")
    ensure
      existing&.update_columns(status: :closed)
    end

    test "do_activate! fails when not pending" do
      active = AcademicYear.create!(
        name: "ActTest", start_date: Date.current, end_date: Date.current + 1.year, status: :active
      )
      assert_raises(ActiveRecord::RecordInvalid) { active.do_activate! }
    ensure
      active&.update_columns(status: :closed)
    end

    test "do_close! transitions active to closed" do
      year = AcademicYear.create!(
        name: "ToClose", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      assert_difference -> { OutboxEvent.count }, 1 do
        year.do_close!
      end
      assert year.closed?
      assert_not_nil year.closed_at
    end

    test "do_close! fails when not active" do
      assert_raises(ActiveRecord::RecordInvalid) { @pending_year.do_close! }
    end

    test "do_close! fails when active accommodations exist" do
      year = AcademicYear.create!(
        name: "WithActiveAcc", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      resident = dormitory_residents(:resident_one_not_settled)
      room = dormitory_rooms(:room_101)
      acc = Accommodation.create!(
        resident: resident,
        room: room,
        academic_year: year,
        application_number: "TEST",
        contract_number: "TEST",
        start_date: Date.current,
        planned_end_date: Date.current + 1.month,
        status: :active
      )
      assert_raises(ActiveRecord::RecordInvalid) { year.do_close! }
      assert_includes year.errors[:base],
                      I18n.t("activerecord.errors.models.dormitory/academic_year.attributes.base.has_active_accommodations")
    ensure
      acc&.destroy!
    end

    test "do_close! succeeds when all accommodations are completed" do
      year = AcademicYear.create!(
        name: "CompletedAcc", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      resident = dormitory_residents(:resident_one_not_settled)
      room = dormitory_rooms(:room_101)
      acc = Accommodation.create!(
        resident: resident,
        room: room,
        academic_year: year,
        application_number: "TEST2",
        contract_number: "TEST2",
        start_date: Date.current,
        planned_end_date: Date.current + 1.month,
        actual_end_date: Date.current,
        status: :completed
      )
      assert_difference -> { OutboxEvent.count }, 1 do
        year.do_close!
      end
      assert year.closed?
    ensure
      acc&.destroy!
    end

    test "do_close! fails when already closed" do
      year = AcademicYear.create!(
        name: "Closed2", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      year.do_close!
      assert_raises(ActiveRecord::RecordInvalid) { year.do_close! }
    end

    test "do_update! fails when closed" do
      year = AcademicYear.create!(
        name: "ToUpdate", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      year.do_close!
      assert_raises(ActiveRecord::RecordInvalid) { year.do_update!(name: "New name") }
    end

    test "do_update! works for pending year" do
      assert_difference -> { OutboxEvent.count }, 1 do
        @pending_year.do_update!(name: "Updated name")
      end
      assert_equal "Updated name", @pending_year.reload.name
    end

    test "do_update! works for active year" do
      year = AcademicYear.create!(
        name: "UpActive", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      year.do_update!(name: "Updated active")
      assert_equal "Updated active", year.reload.name
    ensure
      year&.update_columns(status: :closed)
    end

    test "active scope returns only active years" do
      active = AcademicYear.create!(
        name: "ScopeAct", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      assert_includes AcademicYear.active, active
    ensure
      active&.update_columns(status: :closed)
    end

    test "ordered scope orders by start_date desc" do
      ordered = AcademicYear.ordered
      assert ordered.first.start_date >= ordered.last.start_date
    end

    test "do_discard! discards pending year" do
      assert_difference -> { OutboxEvent.count }, 1 do
        @pending_year.do_discard!
      end
      assert @pending_year.discarded?
    end

    test "do_discard! fails when active" do
      active = AcademicYear.create!(
        name: "DiscardActive", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      assert_raises(ActiveRecord::RecordInvalid) { active.do_discard! }
      assert_includes active.errors[:status],
                      I18n.t("activerecord.errors.models.dormitory/academic_year.attributes.status.cannot_delete_not_pending")
    ensure
      active&.update_columns(status: :closed)
    end

    test "do_discard! fails when closed" do
      year = AcademicYear.create!(
        name: "DiscardClosed", start_date: Date.current,
        end_date: Date.current + 1.year, status: :active
      )
      year.do_close!
      assert_raises(ActiveRecord::RecordInvalid) { year.do_discard! }
    end

    test "allows duplicate name after discard" do
      @pending_year.do_discard!
      new_year = AcademicYear.new(
        name: @pending_year.name, start_date: Date.new(2030, 9, 1), end_date: Date.new(2031, 8, 31)
      )
      assert new_year.valid?
    end

    test "kept scope excludes discarded years" do
      @pending_year.do_discard!
      assert_not_includes AcademicYear.kept, @pending_year
    end

    test "with_discarded includes discarded years" do
      @pending_year.do_discard!
      assert_includes AcademicYear.with_discarded, @pending_year
    end
  end
end
