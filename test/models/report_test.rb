require "test_helper"

class Reporting::ReportTest < ActiveSupport::TestCase
  setup do
    @manager  = users(:manager_user)
    @reporter = users(:reporter_user)
    @reviewer = users(:reviewer_user)
    Current.session = @manager.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  # ── Validations ──────────────────────────────────────────────

  test "requires name" do
    report = Reporting::Report.new(creator: @manager)
    assert_not report.valid?
    assert report.errors[:name].any?
  end

  test "reporter and reviewer must differ" do
    report = reporting_reports(:new_report)
    report.reviewer = @reporter
    assert_not report.valid?
    assert report.errors[:reviewer_id].any?
  end

  test "reporter, reviewer, deadline required when not draft" do
    report = Reporting::Report.new(name: "Test", creator: @manager, status: "new")
    assert_not report.valid?
    assert report.errors[:reporter_id].any?
    assert report.errors[:reviewer_id].any?
    assert report.errors[:deadline].any?
  end

  test "reporter, reviewer, deadline not required for draft" do
    report = Reporting::Report.new(name: "Test", creator: @manager)
    assert report.valid?
  end

  # ── State helpers ────────────────────────────────────────────

  test "initial state is draft" do
    assert Reporting::Report.new(name: "T", creator: @manager).draft?
  end

  test "editable? is true for draft, in_progress, rejected, reopened" do
    %w[draft in_progress rejected reopened].each do |status|
      report = Reporting::Report.new(name: "T", creator: @manager, status: status)
      assert report.editable?, "expected editable? for #{status}"
    end
  end

  test "editable? is false for new, in_review, accepted" do
    %w[new in_review accepted].each do |status|
      report = Reporting::Report.new(name: "T", creator: @manager, status: status)
      assert_not report.editable?, "expected not editable? for #{status}"
    end
  end

  test "all_items_graded? returns true when all items have grades" do
    assert reporting_reports(:in_review_report).all_items_graded?
  end

  test "all_items_graded? returns false with no items" do
    assert_not reporting_reports(:in_progress_report).all_items_graded?
  end

  test "all_items_graded? returns false when any item has no grade" do
    reporting_reports(:in_review_report).report_items.create!(name: "Без оценки")
    assert_not reporting_reports(:in_review_report).all_items_graded?
  end

  test "all_attachments_present? returns true with no items" do
    assert reporting_reports(:in_progress_report).all_attachments_present?
  end

  test "all_attachments_present? returns true when no items require attachments" do
    reporting_reports(:in_progress_report).report_items.create!(name: "Обычный пункт")
    assert reporting_reports(:in_progress_report).all_attachments_present?
  end

  test "all_attachments_present? returns false when attachment required but missing" do
    reporting_reports(:in_progress_report).report_items.create!(name: "С вложением", attachments_required: true)
    assert_not reporting_reports(:in_progress_report).all_attachments_present?
  end

  test "missing_attachment_items lists only items with required missing attachments" do
    report = reporting_reports(:in_progress_report)
    report.report_items.create!(name: "Обычный")
    missing = report.report_items.create!(name: "С обязательным", attachments_required: true)
    assert_equal [ missing ], report.missing_attachment_items
  end

  test "missing_attachment_items is empty when all required attachments attached" do
    report = reporting_reports(:in_progress_report)
    item = report.report_items.create!(name: "С обязательным", attachments_required: true)
    item.attachments.attach(io: StringIO.new("x"), filename: "x.txt", content_type: "text/plain")
    assert_empty report.missing_attachment_items
  end

  # ── do_publish! ──────────────────────────────────────────────

  test "do_publish! transitions draft to new" do
    report = reporting_reports(:draft_report)
    report.update!(reporter: @reporter, reviewer: @reviewer, deadline: 1.week.from_now)
    report.report_items.create!(name: "Пункт")
    report.do_publish!
    assert report.reload.new?
  end

  test "do_publish! creates OutboxEvent" do
    report = reporting_reports(:draft_report)
    report.update!(reporter: @reporter, reviewer: @reviewer, deadline: 1.week.from_now)
    report.report_items.create!(name: "Пункт")
    assert_difference "OutboxEvent.count", 1 do
      report.do_publish!
    end
  end

  test "do_publish! notifies reporter with report.assigned" do
    report = reporting_reports(:draft_report)
    report.update!(reporter: @reporter, reviewer: @reviewer, deadline: 1.week.from_now)
    report.report_items.create!(name: "Пункт")
    assert_difference -> { @reporter.notifications.count }, 1 do
      report.do_publish!
    end
    assert_equal "reporting.report.assigned", @reporter.notifications.last.action
  end

  test "do_publish! fails and does not create OutboxEvent when no items" do
    report = Reporting::Report.create!(name: "Empty Draft", status: "draft", creator: @manager)
    report.update!(reporter: @reporter, reviewer: @reviewer, deadline: 1.week.from_now)
    assert_no_difference "OutboxEvent.count" do
      assert_raises(AASM::InvalidTransition) { report.do_publish! }
    end
    assert report.reload.draft?
  end

  # ── do_take_in_progress! ─────────────────────────────────────

  test "do_take_in_progress! transitions new to in_progress" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:new_report).do_take_in_progress!
    assert reporting_reports(:new_report).reload.in_progress?
  end

  test "do_take_in_progress! creates OutboxEvent" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    assert_difference "OutboxEvent.count", 1 do
      reporting_reports(:new_report).do_take_in_progress!
    end
  end

  test "do_take_in_progress! works from reopened state" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    report = reporting_reports(:rejected_report)
    report.update_column(:status, "reopened")
    report.do_take_in_progress!
    assert report.reload.in_progress?
  end

  # ── do_submit! ───────────────────────────────────────────────

  test "do_submit! transitions in_progress to in_review" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_progress_report).do_submit!
    assert reporting_reports(:in_progress_report).reload.in_review?
  end

  test "do_submit! sets submitted_at" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_progress_report).do_submit!
    assert_not_nil reporting_reports(:in_progress_report).reload.submitted_at
  end

  test "do_submit! creates OutboxEvent and notifies reviewer" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    assert_difference "OutboxEvent.count", 1 do
      assert_difference -> { @reviewer.notifications.count }, 1 do
        reporting_reports(:in_progress_report).do_submit!
      end
    end
    assert_equal "reporting.report.submitted", @reviewer.notifications.last.action
  end

  test "do_submit! fails when required attachments missing" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_progress_report).report_items.create!(name: "Требует файл", attachments_required: true)
    assert_no_difference "OutboxEvent.count" do
      assert_raises(AASM::InvalidTransition) { reporting_reports(:in_progress_report).do_submit! }
    end
    assert reporting_reports(:in_progress_report).reload.in_progress?
  end

  # ── do_reject! ───────────────────────────────────────────────

  test "do_reject! transitions in_review to rejected" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_review_report).do_reject!("Причина")
    assert reporting_reports(:in_review_report).reload.rejected?
  end

  test "do_reject! stores rejection_reason and sets reviewed_at" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_review_report).do_reject!("Недостаточно данных")
    report = reporting_reports(:in_review_report).reload
    assert_equal "Недостаточно данных", report.rejection_reason
    assert_not_nil report.reviewed_at
  end

  test "do_reject! creates OutboxEvent and notifies reporter" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    assert_difference "OutboxEvent.count", 1 do
      assert_difference -> { @reporter.notifications.count }, 1 do
        reporting_reports(:in_review_report).do_reject!("Причина")
      end
    end
    assert_equal "reporting.report.rejected", @reporter.notifications.last.action
  end

  # ── do_accept! ───────────────────────────────────────────────

  test "do_accept! transitions in_review to accepted" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_review_report).do_accept!
    assert reporting_reports(:in_review_report).reload.accepted?
  end

  test "do_accept! calculates and stores total_grade" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    report = reporting_reports(:in_review_report)
    expected = report.report_items.sum(:grade)
    report.do_accept!
    assert_equal expected, report.reload.total_grade
  end

  test "do_accept! sets reviewed_at" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:in_review_report).do_accept!
    assert_not_nil reporting_reports(:in_review_report).reload.reviewed_at
  end

  test "do_accept! creates OutboxEvent and notifies reporter" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    assert_difference "OutboxEvent.count", 1 do
      assert_difference -> { @reporter.notifications.count }, 1 do
        reporting_reports(:in_review_report).do_accept!
      end
    end
    assert_equal "reporting.report.accepted", @reporter.notifications.last.action
  end

  test "do_accept! OutboxEvent payload includes total_grade" do
    Current.session = @reviewer.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    report = reporting_reports(:in_review_report)
    expected_grade = report.report_items.sum(:grade)
    report.do_accept!
    event = OutboxEvent.where(record: report, action: "reporting.report.accepted").last
    assert_not_nil event
    assert_equal expected_grade, event.payload["total_grade"]
  end

  # ── do_reopen! ───────────────────────────────────────────────

  test "do_reopen! transitions rejected to reopened" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    reporting_reports(:rejected_report).do_reopen!
    assert reporting_reports(:rejected_report).reload.reopened?
  end

  test "do_reopen! creates OutboxEvent and notifies reviewer" do
    Current.session = @reporter.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    assert_difference "OutboxEvent.count", 1 do
      assert_difference -> { @reviewer.notifications.count }, 1 do
        reporting_reports(:rejected_report).do_reopen!
      end
    end
    assert_equal "reporting.report.reopened", @reviewer.notifications.last.action
  end
end
