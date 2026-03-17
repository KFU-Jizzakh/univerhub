require "test_helper"

class Reporting::ReportItemTest < ActiveSupport::TestCase
  setup do
    @reviewer = users(:reviewer_user)
    @reporter = users(:reporter_user)
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  # ── Validations ──────────────────────────────────────────────

  test "requires name" do
    item = Reporting::ReportItem.new(report: reporting_reports(:in_review_report))
    assert_not item.valid?
    assert item.errors[:name].any?
  end

  test "grade can be nil" do
    item = Reporting::ReportItem.new(report: reporting_reports(:in_review_report), name: "Пункт")
    assert item.valid?
  end

  test "grade must be >= 0" do
    item = reporting_report_items(:graded_item)
    item.grade = -1
    assert_not item.valid?
    assert item.errors[:grade].any?
  end

  test "grade must be <= max_grade" do
    item = reporting_report_items(:graded_item)
    item.grade = item.max_grade + 1
    assert_not item.valid?
    assert item.errors[:grade].any?
  end

  test "grade can equal max_grade" do
    item = reporting_report_items(:graded_item)
    item.grade = item.max_grade
    assert item.valid?
  end

  test "grade can be 0" do
    item = reporting_report_items(:graded_item)
    item.grade = 0
    assert item.valid?
  end

  # ── do_grade! ────────────────────────────────────────────────

  test "do_grade! returns true and updates grade on valid input" do
    item = reporting_report_items(:graded_item)
    result = item.do_grade!({ grade: 7, grade_comment: "Хорошо" })
    assert result
    assert_equal 7, item.reload.grade
    assert_equal "Хорошо", item.grade_comment
  end

  test "do_grade! creates OutboxEvent on success" do
    item = reporting_report_items(:graded_item)
    assert_difference "OutboxEvent.count", 1 do
      item.do_grade!({ grade: 8 })
    end
  end

  test "do_grade! returns false on invalid grade" do
    item = reporting_report_items(:graded_item)
    result = item.do_grade!({ grade: 999 })
    assert_not result
    assert item.errors[:grade].any?
  end

  test "do_grade! does not create OutboxEvent on failure" do
    item = reporting_report_items(:graded_item)
    assert_no_difference "OutboxEvent.count" do
      item.do_grade!({ grade: 999 })
    end
  end

  test "do_grade! does not persist grade on failure" do
    item = reporting_report_items(:graded_item)
    original_grade = item.grade
    item.do_grade!({ grade: 999 })
    assert_equal original_grade, item.reload.grade
  end

  # ── do_update_content! ───────────────────────────────────────

  test "do_update_content! returns true and updates content" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    item = reporting_report_items(:graded_item)
    result = item.do_update_content!({ content: "Новое содержание" })
    assert result
    assert_equal "Новое содержание", item.reload.content
  end

  test "do_update_content! creates OutboxEvent" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    assert_difference "OutboxEvent.count", 1 do
      reporting_report_items(:graded_item).do_update_content!({ content: "Содержание" })
    end
  end
end
