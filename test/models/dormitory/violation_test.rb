require "test_helper"

class Dormitory::ViolationTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    @resident = dormitory_residents(:resident_two_settled)
  end

  teardown do
    Current.reset
  end

  test "valid violation with all required fields" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
      status: :open,
    )
    assert violation.valid?
  end

  test "invalid without resident" do
    violation = Dormitory::Violation.new(
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:resident], :any?
  end

  test "invalid without violation_type" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:violation_type], :any?
  end

  test "invalid without occurred_at" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      place: "Комната 201",
      description: "Громкая музыка",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:occurred_at], :any?
  end

  test "invalid without place" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      description: "Громкая музыка",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:place], :any?
  end

  test "invalid without description" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:description], :any?
  end

  test "invalid with future occurred_at" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: 1.day.from_now,
      place: "Комната 201",
      description: "Громкая музыка",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:occurred_at], :any?
  end

  test "do_create! creates OutboxEvent" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
      status: :open,
    )
    assert_difference "OutboxEvent.count", 1 do
      violation.do_create!
    end
    assert_equal "dormitory.violation.created", OutboxEvent.last.action
  end

  test "do_update! creates OutboxEvent" do
    violation = dormitory_violations(:violation_open_noise)
    assert_difference "OutboxEvent.count", 1 do
      violation.do_update!(place: "Новое место")
    end
    assert_equal "dormitory.violation.updated", OutboxEvent.last.action
  end

  test "do_discard! creates OutboxEvent" do
    violation = dormitory_violations(:violation_open_noise)
    assert_difference "OutboxEvent.count", 1 do
      violation.do_discard!
    end
    assert_equal "dormitory.violation.discarded", OutboxEvent.last.action
    assert violation.discarded?
  end

  test "reviewed status requires reviewed_at and review_result" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
      status: :reviewed,
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:reviewed_at], :any?
    assert_predicate violation.errors[:review_result], :any?
  end

  test "closed status requires reviewed_at and review_result" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
      status: :closed,
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:reviewed_at], :any?
    assert_predicate violation.errors[:review_result], :any?
  end

  test "open status must not have reviewed_at and review_result" do
    violation = Dormitory::Violation.new(
      resident: @resident,
      violation_type: :noise,
      occurred_at: Time.current,
      place: "Комната 201",
      description: "Громкая музыка",
      status: :open,
      reviewed_at: Date.current,
      review_result: "Some result",
    )
    assert_not violation.valid?
    assert_predicate violation.errors[:reviewed_at], :any?
    assert_predicate violation.errors[:review_result], :any?
  end

  test "ordered scope returns newest first" do
    violations = Dormitory::Violation.ordered.to_a
    assert violations.first.occurred_at >= violations.last.occurred_at if violations.size > 1
  end

  test "by_resident scope filters by resident_id" do
    violations = Dormitory::Violation.by_resident(@resident.id)
    violations.each do |v|
      assert_equal @resident.id, v.resident_id
    end
  end

  test "status enum values" do
    assert_equal 0, Dormitory::Violation.statuses[:open]
    assert_equal 1, Dormitory::Violation.statuses[:reviewed]
    assert_equal 2, Dormitory::Violation.statuses[:closed]
  end

  test "violation_type enum values" do
    assert_equal 0, Dormitory::Violation.violation_types[:noise]
    assert_equal 6, Dormitory::Violation.violation_types[:other]
  end
end
