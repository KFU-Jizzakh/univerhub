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
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ001",
    )
    assert resident.valid?
  end

  test "initial status is not_settled" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ002",
    )
    assert resident.not_settled?
  end

  test "initial current_room_id is nil" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ003",
    )
    assert_nil resident.current_room_id
  end

  test "invalid without last_name" do
    resident = Dormitory::Resident.new(
      first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ004",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:last_name], :any?
  end

  test "invalid without first_name" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ005",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:first_name], :any?
  end

  test "invalid without gender" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван",
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ006",
      gender: nil,
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:gender], :any?
  end

  test "invalid without date_of_birth" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      student_ticket_number: "UNIQ007",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:date_of_birth], :any?
  end

  test "invalid without student_ticket_number" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago,
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:student_ticket_number], :any?
  end

  test "valid name with hyphen" do
    resident = Dormitory::Resident.new(
      last_name: "Иванова-Петрова", first_name: "Мария", gender: :female,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ009",
    )
    assert resident.valid?
  end

  test "valid name with space" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Жан Поль", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ010",
    )
    assert resident.valid?
  end

  test "invalid name with digits" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов123", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ011",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:last_name], :any?
  end

  test "date_of_birth in future is invalid" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 1.day.from_now, student_ticket_number: "UNIQ012",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:date_of_birth], :any?
  end

  test "phone with invalid format" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ013",
      phone: "abc",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:phone], :any?
  end

  test "phone with valid E.164 format" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ014",
      phone: "+79001234567",
    )
    assert resident.valid?
  end

  test "email with invalid format" do
    resident = Dormitory::Resident.new(
      last_name: "Иванов", first_name: "Иван", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ015",
      email: "not-email",
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:email], :any?
  end

  test "duplicate student_ticket_number among kept" do
    existing = dormitory_residents(:resident_one_not_settled)
    resident = Dormitory::Resident.new(
      last_name: "Новый", first_name: "Человек", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: existing.student_ticket_number,
    )
    assert_not resident.valid?
    assert_predicate resident.errors[:student_ticket_number], :any?
  end

  test "duplicate student_ticket_number allowed for discarded" do
    existing = dormitory_residents(:resident_one_not_settled)
    existing.discard!
    resident = Dormitory::Resident.new(
      last_name: "Новый", first_name: "Человек", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "АБ123456",
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
      date_of_birth: 20.years.ago, student_ticket_number: "UNIQ016",
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

  test "optional middle_name with valid format" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", middle_name: "Тестович",
      gender: :male, date_of_birth: 20.years.ago,
      student_ticket_number: "UNIQ017",
    )
    assert resident.valid?
  end

  test "blank middle_name is valid" do
    resident = Dormitory::Resident.new(
      last_name: "Тест", first_name: "Тест", middle_name: "",
      gender: :male, date_of_birth: 20.years.ago,
      student_ticket_number: "UNIQ018",
    )
    assert resident.valid?
  end
end
