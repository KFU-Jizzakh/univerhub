require "test_helper"

class Dormitory::ResidentTest < ActiveSupport::TestCase
  setup do
    @building = dormitory_buildings(:building_one)
    @admin = users(:admin_user)
    Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown do
    Current.reset
  end

  test "valid resident with all required fields" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ001",
    )
    assert resident.valid?
  end

  test "initial status is not_settled" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ002",
    )
    assert resident.not_settled?
  end

  test "initial current_room_id is nil" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ003",
    )
    assert_nil resident.current_room_id
  end

  test "invalid without last_name" do
    resident = Dormitory::Resident.new(
      first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ004",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:last_name], :any?
  end

  test "invalid without first_name" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ005",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:first_name], :any?
  end

  test "invalid without gender" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван",
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ006",
      gender: nil,
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:gender], :any?
  end

  test "invalid without date_of_birth" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      course: 1, student_ticket_number: "UNIQ007",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:date_of_birth], :any?
  end

  test "invalid without student_ticket_number" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1,
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:student_ticket_number], :any?
  end

  test "valid name with hyphen" do
    resident = Dormitory::Resident.new(
      last_name: "Иванова-Петрова", first_name: "Мария", gender: :female,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ009",
    )
    assert resident.valid?
  end

  test "valid name with space" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Жан Поль", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ010",
    )
    assert resident.valid?
  end

  test "invalid name with digits" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов123", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ011",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:last_name], :any?
  end

  test "date_of_birth in future is invalid" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 1.day.from_now, course: 1, student_ticket_number: "UNIQ012",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:date_of_birth], :any?
  end

  test "phone with invalid format" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ013",
      phone: "abc",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:phone], :any?
  end

  test "phone with valid E.164 format" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ014",
      phone: "+79001234567",
    )
    assert resident.valid?
  end

  test "email with invalid format" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ015",
      email: "not-email",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:email], :any?
  end

  test "duplicate student_ticket_number among kept" do
    existing = dormitory_residents(:resident_one_not_settled)
    resident = Dormitory::Resident.new(
      last_name: "Новый", first_name: "Человек", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: existing.student_ticket_number,
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:student_ticket_number], :any?
  end

  test "duplicate student_ticket_number allowed for discarded" do
    existing = dormitory_residents(:resident_one_not_settled)
    existing.discard!
    resident = Dormitory::Resident.new(
      last_name: "Новый", first_name: "Человек", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "АБ123456",
    )
    assert resident.valid?
  end

  test "gender immutable when settled" do
    resident = dormitory_residents(:resident_two_settled)
    resident.gender = :male
    assert_not resident.valid?
    assert_predicate resident.errors[:gender], :any?
  end

  test "gender immutable when temporarily_absent" do
    resident = dormitory_residents(:resident_two_settled)
    resident.update_column(:status, :temporarily_absent)
    resident.reload
    resident.gender = :male
    assert_not resident.valid?
    assert_predicate resident.errors[:gender], :any?
  end

  test "gender changeable when not_settled" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.gender = :female
    assert resident.valid?
  end

  test "gender changeable when evicted" do
    resident = dormitory_residents(:resident_three_evicted)
    resident.gender = :female
    assert resident.valid?
  end

  test "course_editable? returns true for not_settled resident" do
    assert dormitory_residents(:resident_one_not_settled).course_editable?
  end

  test "course_editable? returns true for evicted resident" do
    assert dormitory_residents(:resident_three_evicted).course_editable?
  end

  test "course_editable? returns false for settled resident" do
    assert_not dormitory_residents(:resident_two_settled).course_editable?
  end

  test "active_accommodation excludes discarded accommodations" do
    resident = dormitory_residents(:resident_two_settled)
    acc = resident.active_accommodation
    assert_not_nil acc

    acc.discard!
    assert_nil resident.reload.active_accommodation
  end

  test "full_name concatenates names" do
    resident = dormitory_residents(:resident_one_not_settled)
    assert_equal "Иванов Иван Иванович", resident.full_name
  end

  test "full_name without middle_name" do
    resident = dormitory_residents(:resident_three_evicted)
    assert_equal "Сидоров Алексей", resident.full_name
  end

  test "do_create! creates OutboxEvent" do
    resident = Dormitory::Resident.new(
      last_name: "Тестов", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ016",
    )
    assert_difference "OutboxEvent.count", 1 do
      resident.do_create!
    end
    assert_equal "dormitory.resident.created", OutboxEvent.last.action
  end

  test "do_update! creates OutboxEvent" do
    resident = dormitory_residents(:resident_one_not_settled)
    assert_difference "OutboxEvent.count", 1 do
      resident.do_update!(phone: "+79111111111")
    end
  end

  test "do_discard! discards not_settled resident" do
    resident = dormitory_residents(:resident_one_not_settled)
    assert_difference "OutboxEvent.count", 1 do
      resident.do_discard!
    end
    assert resident.reload.discarded?
  end

  test "do_discard! discards evicted resident" do
    resident = dormitory_residents(:resident_three_evicted)
    resident.do_discard!
    assert resident.reload.discarded?
  end

  test "do_discard! fails for settled resident" do
    resident = dormitory_residents(:resident_two_settled)
    assert_no_difference "OutboxEvent.count" do
      assert_raises(ActiveRecord::RecordInvalid) { resident.do_discard! }
    end
  end

  test "do_discard! fails for temporarily_absent resident" do
    resident = dormitory_residents(:resident_two_settled)
    resident.update_column(:status, :temporarily_absent)
    assert_raises(ActiveRecord::RecordInvalid) { resident.do_discard! }
  end

  test "do_discard! is idempotent for already discarded resident" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.discard!

    assert_no_difference "OutboxEvent.count" do
      assert resident.do_discard!
    end
    assert resident.reload.discarded?
  end

  test "do_discard! rejects pending accommodation and releases the reserved place" do
    resident = dormitory_residents(:resident_one_not_settled)
    room = dormitory_rooms(:room_101)
    acc = Dormitory::Accommodation.create!(
      resident: resident, room: room, course: resident.course,
      application_number: "З-ПН", contract_number: "Д-ПН",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :pending, bed_label: "A"
    )
    room.update!(current_occupancy: 1)
    room.update_column(:status, "partially_occupied")

    assert_difference "Dormitory::Accommodation.kept.where(status: :pending).count", -1 do
      resident.do_discard!
    end

    assert resident.reload.discarded?
    assert acc.reload.cancelled?
    assert_equal 0, room.reload.current_occupancy
    assert_equal "free", room.status
  end

  test "do_discard! cancels pending accommodation when its room is discarded" do
    resident = dormitory_residents(:resident_one_not_settled)
    room = dormitory_rooms(:room_101)
    acc = Dormitory::Accommodation.create!(
      resident: resident, room: room, course: resident.course,
      application_number: "З-КМ", contract_number: "Д-КМ",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :pending, bed_label: "A"
    )
    room.discard!

    assert_difference "OutboxEvent.count", 2 do
      assert resident.do_discard!
    end

    assert resident.reload.discarded?
    assert acc.reload.cancelled?
    assert_equal "dormitory.accommodation.rejected", OutboxEvent.order(:id).second_to_last.action
  end

  test "do_discard! succeeds when pending accommodation was concurrently cancelled" do
    resident = dormitory_residents(:resident_one_not_settled)
    room = dormitory_rooms(:room_101)
    acc = Dormitory::Accommodation.create!(
      resident: resident, room: room, course: resident.course,
      application_number: "З-КОН", contract_number: "Д-КОН",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :pending, bed_label: "A"
    )
    acc.update_columns(status: "cancelled", actual_end_date: Date.current)

    assert resident.do_discard!
    assert resident.reload.discarded?
  end

  test "do_discard! recalibrates room status after releasing a zero-occupancy room reservation" do
    resident = dormitory_residents(:resident_one_not_settled)
    room = dormitory_rooms(:room_101)
    acc = Dormitory::Accommodation.create!(
      resident: resident, room: room, course: resident.course,
      application_number: "З-КАЛ", contract_number: "Д-КАЛ",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :pending, bed_label: "A"
    )
    room.update_column(:status, "partially_occupied")

    assert_difference "OutboxEvent.count", 3 do
      resident.do_discard!
    end

    assert resident.reload.discarded?
    assert acc.reload.cancelled?
    assert_equal 0, room.reload.current_occupancy
    assert_equal "free", room.status
  end

  test "do_discard! skips audit event when resident was discarded concurrently" do
    resident = dormitory_residents(:resident_one_not_settled)
    discarded_checks = 0
    resident.define_singleton_method(:discarded?) { (discarded_checks += 1) > 1 }

    assert_no_difference "OutboxEvent.count" do
      assert resident.do_discard!
    end

    assert_nil resident.reload.discarded_at
  end

  test "do_discard! raises when pending accommodation release fails" do
    resident = dormitory_residents(:resident_one_not_settled)
    room = dormitory_rooms(:room_101)
    Dormitory::Accommodation.create!(
      resident: resident, room: room, course: resident.course,
      application_number: "З-ОШБ", contract_number: "Д-ОШБ",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :pending, bed_label: "A"
    )
    room.update!(current_occupancy: 1)
    room.update_column(:status, "partially_occupied")

    Dormitory::Accommodation.class_eval do
      alias_method :__original_do_reject, :do_reject!
      def do_reject!
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    assert_no_difference "OutboxEvent.count" do
      assert_raises(ActiveRecord::RecordInvalid) { resident.do_discard! }
    end
    assert_not resident.reload.discarded?
    assert_equal 1, room.reload.current_occupancy
  ensure
    Dormitory::Accommodation.class_eval do
      alias_method :do_reject!, :__original_do_reject
      remove_method :__original_do_reject
    end
  end

  test "kept scope excludes discarded" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.discard!
    assert_not_includes Dormitory::Resident.kept, resident
    assert_includes Dormitory::Resident.with_discarded, resident
  end

  test "ordered scope sorts by last_name, first_name" do
    residents = Dormitory::Resident.kept.ordered
    assert residents.first.last_name <= residents.last.last_name
  end

  test "search_by_name scope finds by last_name" do
    results = Dormitory::Resident.search_by_name("Иванов")
    assert_includes results, dormitory_residents(:resident_one_not_settled)
  end

  test "search_by_name scope finds by first_name" do
    results = Dormitory::Resident.search_by_name("Мария")
    assert_includes results, dormitory_residents(:resident_two_settled)
  end

  test "search_by_name is case insensitive" do
    results = Dormitory::Resident.search_by_name("иванов")
    assert_includes results, dormitory_residents(:resident_one_not_settled)
  end

  test "document numbers are optional" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ018",
    )
    assert resident.valid?
  end

  test "accepts document numbers" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ019",
      application_number: "З-001", contract_number: "Д-001",
    )
    assert resident.valid?
  end

  test "invalid when application file attached without application number" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
    )
    assert_not resident.valid?
    assert_includes resident.errors[:application_number], "укажите номер заявления, если прикреплён файл"
  end

  test "invalid when contract file attached without contract number" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.contract_file.attach(
      io: StringIO.new("cnt"), filename: "contract.pdf", content_type: "application/pdf"
    )
    assert_not resident.valid?
    assert_includes resident.errors[:contract_number], "укажите номер договора, если прикреплён файл"
  end

  test "valid when file attached with number" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.application_number = "З-001"
    resident.contract_number = "Д-001"
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
    )
    resident.contract_file.attach(
      io: StringIO.new("cnt"), filename: "contract.pdf", content_type: "application/pdf"
    )
    assert resident.valid?
  end

  test "accepts doc/docx for application and contract files" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.application_number = "З-001"
    resident.contract_number = "Д-001"
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.doc", content_type: "application/msword"
    )
    resident.contract_file.attach(
      io: StringIO.new("cnt"), filename: "contract.docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
    assert resident.valid?
  end

  test "valid when number present without file" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, course: 1, student_ticket_number: "UNIQ020",
      application_number: "З-001", contract_number: "Д-001",
    )
    assert resident.valid?
  end

  test "rejects invalid application file format" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.application_file.attach(
      io: StringIO.new("not a pdf"), filename: "app.txt", content_type: "text/plain"
    )
    assert_not resident.valid?
    assert_includes resident.errors[:application_file], I18n.t("activerecord.errors.models.dormitory/resident.attributes.application_file.invalid_file_format")
  end

  test "rejects oversized contract file" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.contract_file.attach(
      io: StringIO.new("x" * (10.megabytes + 1)), filename: "contract.pdf", content_type: "application/pdf"
    )
    assert_not resident.valid?
    assert_includes resident.errors[:contract_file], "Размер файла превышает 10 МБ."
  end

  test "copy_documents_to copies numbers and files to accommodation" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.update!(application_number: "З-100", contract_number: "Д-100")
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
    )
    resident.contract_file.attach(
      io: StringIO.new("cnt"), filename: "contract.pdf", content_type: "application/pdf"
    )

    accommodation = Dormitory::Accommodation.new(resident: resident)
    resident.copy_documents_to(accommodation)

    assert_equal "З-100", accommodation.application_number
    assert_equal "Д-100", accommodation.contract_number
    assert accommodation.application_file.attached?
    assert accommodation.contract_file.attached?
  end

  test "copy_documents_to does not overwrite existing accommodation documents" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.update!(application_number: "З-100", contract_number: "Д-100")
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
    )

    accommodation = Dormitory::Accommodation.new(
      resident: resident, application_number: "З-999", contract_number: "Д-999"
    )
    accommodation.application_file.attach(
      io: StringIO.new("mine"), filename: "mine.pdf", content_type: "application/pdf"
    )

    resident.copy_documents_to(accommodation)

    assert_equal "З-999", accommodation.application_number
    assert_equal "Д-999", accommodation.contract_number
    assert_equal "mine.pdf", accommodation.application_file.filename.to_s
    assert_not accommodation.contract_file.attached?
  end

  test "copy_documents_to copies numbers when accommodation value is blank" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.update!(application_number: "З-100", contract_number: "Д-100")

    accommodation = Dormitory::Accommodation.new(
      resident: resident, application_number: "", contract_number: ""
    )

    resident.copy_documents_to(accommodation)

    assert_equal "З-100", accommodation.application_number
    assert_equal "Д-100", accommodation.contract_number
  end

  test "copy_documents_to does nothing when resident already has accommodations" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.update!(application_number: "З-100", contract_number: "Д-100")
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
    )
    Dormitory::Accommodation.create!(
      resident: resident,
      room: dormitory_rooms(:room_101),
      application_number: "З-OLD",
      contract_number: "Д-OLD",
      start_date: Date.current,
      planned_end_date: Date.current + 1.year
    )

    accommodation = Dormitory::Accommodation.new(resident: resident)
    resident.copy_documents_to(accommodation)

    assert_nil accommodation.application_number
    assert_nil accommodation.contract_number
    assert_not accommodation.application_file.attached?
  end

  test "copy_documents_to copies documents when resident has only discarded accommodations" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.update!(application_number: "З-100", contract_number: "Д-100")
    resident.application_file.attach(
      io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
    )
    Dormitory::Accommodation.create!(
      resident: resident,
      room: dormitory_rooms(:room_101),
      application_number: "З-OLD",
      contract_number: "Д-OLD",
      start_date: Date.current,
      planned_end_date: Date.current + 1.year
    ).discard!

    accommodation = Dormitory::Accommodation.new(resident: resident)
    resident.copy_documents_to(accommodation)

    assert_equal "З-100", accommodation.application_number
    assert_equal "Д-100", accommodation.contract_number
    assert accommodation.application_file.attached?
  end

  test "course defaults to 1" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ021",
    )
    assert_equal 1, resident.course
    assert resident.valid?
  end

  test "course must be within 1..6" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male, course: 7,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ022",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:course], :any?
  end

  test "course changeable when not_settled" do
    resident = dormitory_residents(:resident_one_not_settled)
    resident.course = 4
    assert resident.valid?
  end

  test "course immutable when settled" do
    resident = dormitory_residents(:resident_two_settled)
    resident.course = 5
    assert_not resident.valid?
    assert_predicate resident.errors[:course], :any?
  end

  test "course immutable when pending accommodation exists" do
    resident = dormitory_residents(:resident_one_not_settled)
    room = dormitory_rooms(:room_102)
    Dormitory::Accommodation.create!(
      resident: resident, room: room, course: resident.course,
      application_number: "З-ПН", contract_number: "Д-ПН",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:active_year_2025_2026),
      status: :pending
    )
    resident.reload
    resident.course = 5
    assert_not resident.valid?
    assert_predicate resident.errors[:course], :any?
  end

  test "optional middle_name with valid format" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", middle_name: "Тестович",
      gender: :male, date_of_birth: 20.years.ago, course: 1,
      student_ticket_number: "UNIQ017",
    )
    assert resident.valid?
  end

  test "blank middle_name is valid" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", middle_name: "",
      gender: :male, date_of_birth: 20.years.ago, course: 1,
      student_ticket_number: "UNIQ018",
    )
    assert resident.valid?
  end
end
