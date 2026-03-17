require "test_helper"

class Reporting::ReportTemplatePolicyTest < ActiveSupport::TestCase
  setup do
    @admin           = users(:admin_user)
    @manager         = users(:manager_user)
    @reporter        = users(:reporter_user)
    @visitor         = users(:visitor_user)
    @reporting_admin = users(:reporting_admin_user)

    @draft     = reporting_report_templates(:draft_template)
    @published = reporting_report_templates(:published_template)
  end

  def policy(user, record)
    Reporting::ReportTemplatePolicy.new(user, record)
  end

  test "index? is true for everyone" do
    [ @admin, @manager, @reporter, @visitor, @reporting_admin ].each do |u|
      assert policy(u, @draft).index?
    end
  end

  test "show? allows admin, reporting.admin and report_manager for drafts" do
    assert policy(@admin, @draft).show?
    assert policy(@manager, @draft).show?
    assert policy(@reporting_admin, @draft).show?
  end

  test "show? denies non-staff for draft" do
    assert_not policy(@reporter, @draft).show?
    assert_not policy(@visitor, @draft).show?
  end

  test "show? allows anyone when template is published" do
    [ @admin, @manager, @reporter, @visitor, @reporting_admin ].each do |u|
      assert policy(u, @published).show?
    end
  end

  test "create? requires report_manager or reporting.admin" do
    assert policy(@manager, Reporting::ReportTemplate.new).create?
    assert policy(@reporting_admin, Reporting::ReportTemplate.new).create?
    assert policy(@admin, Reporting::ReportTemplate.new).create?
    [ @reporter, @visitor ].each do |u|
      assert_not policy(u, Reporting::ReportTemplate.new).create?
    end
  end

  test "update? requires owner_manager and draft or reporting.admin" do
    assert policy(@manager, @draft).update?
    assert_not policy(@manager, @published).update?
    assert policy(@reporting_admin, @draft).update?
    assert policy(@reporting_admin, @published).update?
    assert policy(@admin, @draft).update?
    assert policy(@admin, @published).update?
    assert_not policy(@reporter, @draft).update?
  end

  test "update? denied for non-owner manager" do
    other = User.create!(email_address: "other_mgr@t.local", password: "password123")
    other.roles << roles(:reporting_manager)
    assert_not policy(other, @draft).update?
  end

  test "destroy? requires owner_manager and draft or reporting.admin" do
    assert policy(@manager, @draft).destroy?
    assert_not policy(@manager, @published).destroy?
    assert policy(@reporting_admin, @draft).destroy?
    assert policy(@reporting_admin, @published).destroy?
    assert policy(@admin, @draft).destroy?
    assert policy(@admin, @published).destroy?
    assert_not policy(@reporter, @draft).destroy?
  end

  test "publish? requires owner_manager and draft or reporting.admin" do
    assert policy(@manager, @draft).publish?
    assert_not policy(@manager, @published).publish?
    assert policy(@reporting_admin, @draft).publish?
    assert policy(@reporting_admin, @published).publish?
    assert policy(@admin, @draft).publish?
    assert policy(@admin, @published).publish?
    assert_not policy(@reporter, @draft).publish?
  end

  test "archive? requires owner_manager and published or reporting.admin" do
    assert policy(@manager, @published).archive?
    assert_not policy(@manager, @draft).archive?
    assert policy(@reporting_admin, @published).archive?
    assert policy(@reporting_admin, @draft).archive?
    assert policy(@admin, @published).archive?
    assert policy(@admin, @draft).archive?
    assert_not policy(@reporter, @published).archive?
  end

  # ── Scope ────────────────────────────────────────────────────
  test "scope returns all for admin, report_manager, and reporting.admin" do
    assert_equal Reporting::ReportTemplate.count, Reporting::ReportTemplatePolicy::Scope.new(@admin, Reporting::ReportTemplate.all).resolve.count
    assert_equal Reporting::ReportTemplate.count, Reporting::ReportTemplatePolicy::Scope.new(@manager, Reporting::ReportTemplate.all).resolve.count
    assert_equal Reporting::ReportTemplate.count, Reporting::ReportTemplatePolicy::Scope.new(@reporting_admin, Reporting::ReportTemplate.all).resolve.count
  end

  test "scope returns only published for non-staff" do
    result = Reporting::ReportTemplatePolicy::Scope.new(@reporter, Reporting::ReportTemplate.all).resolve
    assert_includes result, @published
    assert_not_includes result, @draft
  end
end
