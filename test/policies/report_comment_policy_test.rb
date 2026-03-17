require "test_helper"

class Reporting::ReportCommentPolicyTest < ActiveSupport::TestCase
  setup do
    @admin           = users(:admin_user)
    @manager         = users(:manager_user)
    @reporter        = users(:reporter_user)
    @visitor         = users(:visitor_user)
    @reporting_admin = users(:reporting_admin_user)
    @comment         = reporting_reports(:new_report).comments.create!(user: @manager, body: "Тест")
  end

  def policy(user)
    Reporting::ReportCommentPolicy.new(user, @comment)
  end

  test "show? delegates to Reporting::ReportPolicy#access_comments?" do
    assert policy(@admin).show?
    assert policy(@manager).show?
    assert policy(@reporter).show?
    assert policy(@reporting_admin).show?
    assert_not policy(@visitor).show?
  end

  test "create? delegates to Reporting::ReportPolicy#access_comments?" do
    assert policy(@admin).create?
    assert policy(@reporter).create?
    assert policy(@reporting_admin).create?
    assert_not policy(@visitor).create?
  end

  test "destroy? allowed for author" do
    assert policy(@manager).destroy?
  end

  test "destroy? allowed for admin even if not author" do
    assert policy(@admin).destroy?
  end

  test "destroy? allowed for reporting.admin even if not author" do
    assert policy(@reporting_admin).destroy?
  end

  test "destroy? denied for non-author non-admin" do
    assert_not policy(@reporter).destroy?
  end
end
