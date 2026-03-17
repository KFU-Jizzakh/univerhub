require "test_helper"

class Reporting::ReportPolicyTest < ActiveSupport::TestCase
  setup do
    @admin           = users(:admin_user)
    @manager         = users(:manager_user)
    @reporter        = users(:reporter_user)
    @reviewer        = users(:reviewer_user)
    @supervisor      = users(:supervisor_user)
    @visitor         = users(:visitor_user)
    @reporting_admin = users(:reporting_admin_user)
  end

  def policy(user, record)
    Reporting::ReportPolicy.new(user, record)
  end

  # ── index? ───────────────────────────────────────────────────
  test "index? is true for all users" do
    [ @admin, @manager, @reporter, @reviewer, @supervisor, @visitor, @reporting_admin ].each do |u|
      assert policy(u, reporting_reports(:new_report)).index?
    end
  end

  # ── show? ────────────────────────────────────────────────────
  test "show? allows admin, supervisor, creator, reporter, reviewer, reporting.admin" do
    report = reporting_reports(:new_report)
    [ @admin, @manager, @reporter, @reviewer, @supervisor, @reporting_admin ].each do |u|
      assert policy(u, report).show?, "expected show? true for #{u.email_address}"
    end
  end

  test "show? allows visitor on non-draft" do
    assert policy(@visitor, reporting_reports(:new_report)).show?
  end

  test "show? denies visitor on draft" do
    assert_not policy(@visitor, reporting_reports(:draft_report)).show?
  end

  test "show? denies unrelated reporter on another's report" do
    other = User.create!(email_address: "other@t.local", password: "password123")
    other.roles << roles(:reporting_reporter)
    assert_not policy(other, reporting_reports(:new_report)).show?
  end

  # ── create? ──────────────────────────────────────────────────
  test "create? allowed for report_manager and reporting.admin" do
    assert policy(@manager, Reporting::Report.new).create?
    assert policy(@reporting_admin, Reporting::Report.new).create?
    assert policy(@admin, Reporting::Report.new).create?
    [ @reporter, @reviewer, @supervisor, @visitor ].each do |u|
      assert_not policy(u, Reporting::Report.new).create?
    end
  end

  # ── update? / destroy? / publish? ────────────────────────────
  test "update? requires manager + draft + creator or reporting.admin" do
    assert policy(@manager, reporting_reports(:draft_report)).update?
    assert_not policy(@manager, reporting_reports(:new_report)).update?
    assert_not policy(@reporter, reporting_reports(:draft_report)).update?
    assert policy(@reporting_admin, reporting_reports(:new_report)).update?
    assert policy(@reporting_admin, reporting_reports(:draft_report)).update?
    assert policy(@admin, reporting_reports(:new_report)).update?
    assert policy(@admin, reporting_reports(:draft_report)).update?
  end

  test "destroy? requires manager + draft + creator or reporting.admin" do
    assert policy(@manager, reporting_reports(:draft_report)).destroy?
    assert_not policy(@manager, reporting_reports(:new_report)).destroy?
    assert policy(@reporting_admin, reporting_reports(:new_report)).destroy?
    assert policy(@admin, reporting_reports(:new_report)).destroy?
  end

  test "publish? requires manager + draft + creator or reporting.admin" do
    assert policy(@manager, reporting_reports(:draft_report)).publish?
    assert_not policy(@manager, reporting_reports(:new_report)).publish?
    assert policy(@reporting_admin, reporting_reports(:new_report)).publish?
    assert policy(@admin, reporting_reports(:new_report)).publish?
  end

  # ── update_items? ────────────────────────────────────────────
  test "update_items? requires reporter + editable + assigned or reporting.admin" do
    assert policy(@reporter, reporting_reports(:in_progress_report)).update_items?
    assert_not policy(@reporter, reporting_reports(:in_review_report)).update_items?
    assert_not policy(@manager, reporting_reports(:in_progress_report)).update_items?
    assert policy(@reporting_admin, reporting_reports(:in_progress_report)).update_items?
    assert policy(@admin, reporting_reports(:in_progress_report)).update_items?
  end

  # ── submit? / take_in_progress? ──────────────────────────────
  test "submit? requires reporter on in_progress or reporting.admin" do
    assert policy(@reporter, reporting_reports(:in_progress_report)).submit?
    assert_not policy(@reporter, reporting_reports(:new_report)).submit?
    assert_not policy(@reviewer, reporting_reports(:in_progress_report)).submit?
    assert policy(@reporting_admin, reporting_reports(:in_progress_report)).submit?
    assert policy(@admin, reporting_reports(:in_progress_report)).submit?
  end

  test "take_in_progress? requires reporter on new or reopened or reporting.admin" do
    assert policy(@reporter, reporting_reports(:new_report)).take_in_progress?
    assert_not policy(@reporter, reporting_reports(:in_progress_report)).take_in_progress?
    assert policy(@reporting_admin, reporting_reports(:new_report)).take_in_progress?
    assert policy(@admin, reporting_reports(:new_report)).take_in_progress?
  end

  # ── accept? / reject? / grade? ───────────────────────────────
  test "grade? requires reviewer on in_review or reporting.admin" do
    assert policy(@reviewer, reporting_reports(:in_review_report)).grade?
    assert_not policy(@reviewer, reporting_reports(:in_progress_report)).grade?
    assert_not policy(@reporter, reporting_reports(:in_review_report)).grade?
    assert policy(@reporting_admin, reporting_reports(:in_review_report)).grade?
    assert policy(@admin, reporting_reports(:in_review_report)).grade?
  end

  test "accept? requires reviewer + in_review + all items graded or reporting.admin" do
    assert policy(@reviewer, reporting_reports(:in_review_report)).accept?
    assert policy(@reporting_admin, reporting_reports(:in_review_report)).accept?
    assert policy(@admin, reporting_reports(:in_review_report)).accept?
  end

  test "accept? denied when not all items graded" do
    reporting_reports(:in_review_report).report_items.create!(name: "Без оценки")
    assert_not policy(@reviewer, reporting_reports(:in_review_report)).accept?
  end

  test "reject? requires reviewer on in_review or reporting.admin" do
    assert policy(@reviewer, reporting_reports(:in_review_report)).reject?
    assert_not policy(@reviewer, reporting_reports(:in_progress_report)).reject?
    assert policy(@reporting_admin, reporting_reports(:in_review_report)).reject?
    assert policy(@admin, reporting_reports(:in_review_report)).reject?
  end

  # ── reopen? ──────────────────────────────────────────────────
  test "reopen? requires reporter on rejected or reporting.admin" do
    assert policy(@reporter, reporting_reports(:rejected_report)).reopen?
    assert_not policy(@reporter, reporting_reports(:new_report)).reopen?
    assert_not policy(@reviewer, reporting_reports(:rejected_report)).reopen?
    assert policy(@reporting_admin, reporting_reports(:rejected_report)).reopen?
    assert policy(@admin, reporting_reports(:rejected_report)).reopen?
  end

  # ── access_comments? / view_history? ─────────────────────────
  test "access_comments? allowed for staff roles, denied for visitor" do
    [ @admin, @manager, @reporter, @reviewer, @supervisor, @reporting_admin ].each do |u|
      assert policy(u, reporting_reports(:new_report)).access_comments?
    end
    assert_not policy(@visitor, reporting_reports(:new_report)).access_comments?
  end

  test "view_history? delegates to access_comments?" do
    assert policy(@admin, reporting_reports(:new_report)).view_history?
    assert policy(@reporting_admin, reporting_reports(:new_report)).view_history?
    assert_not policy(@visitor, reporting_reports(:new_report)).view_history?
  end

  # ── pdf? ──────────────────────────────────────────────────────
  test "pdf? delegates to show?" do
    assert policy(@admin, reporting_reports(:new_report)).pdf?
    assert policy(@reporter, reporting_reports(:new_report)).pdf?
    assert_not policy(@visitor, reporting_reports(:draft_report)).pdf?
  end

  # ── regenerate_pdf? ────────────────────────────────────────────
  test "regenerate_pdf? allowed for reporting.admin, reporting.manager, and creator" do
    assert policy(@reporting_admin, reporting_reports(:new_report)).regenerate_pdf?
    assert policy(@manager, reporting_reports(:draft_report)).regenerate_pdf?
    assert_not policy(@reporter, reporting_reports(:new_report)).regenerate_pdf?
    assert_not policy(@reviewer, reporting_reports(:in_review_report)).regenerate_pdf?
  end

  # ── Scope ────────────────────────────────────────────────────
  test "scope returns all for admin, supervisor, and reporting.admin" do
    assert_equal Reporting::Report.count, Reporting::ReportPolicy::Scope.new(@admin, Reporting::Report.all).resolve.count
    assert_equal Reporting::Report.count, Reporting::ReportPolicy::Scope.new(@supervisor, Reporting::Report.all).resolve.count
    assert_equal Reporting::Report.count, Reporting::ReportPolicy::Scope.new(@reporting_admin, Reporting::Report.all).resolve.count
  end

  test "scope excludes drafts for visitor" do
    result = Reporting::ReportPolicy::Scope.new(@visitor, Reporting::Report.all).resolve
    assert_not_includes result, reporting_reports(:draft_report)
    assert_includes result, reporting_reports(:new_report)
  end

  test "scope for manager returns only owned" do
    result = Reporting::ReportPolicy::Scope.new(@manager, Reporting::Report.all).resolve
    result.each { |r| assert_equal @manager.id, r.creator_id }
  end

  test "scope for reporter returns only assigned" do
    result = Reporting::ReportPolicy::Scope.new(@reporter, Reporting::Report.all).resolve
    result.each { |r| assert_equal @reporter.id, r.reporter_id }
  end

  test "scope for reviewer returns only assigned" do
    result = Reporting::ReportPolicy::Scope.new(@reviewer, Reporting::Report.all).resolve
    result.each { |r| assert_equal @reviewer.id, r.reviewer_id }
  end

  test "scope for role-less user returns none" do
    unknown = User.create!(email_address: "nobody@t.local", password: "password123")
    assert_empty Reporting::ReportPolicy::Scope.new(unknown, Reporting::Report.all).resolve
  end
end
