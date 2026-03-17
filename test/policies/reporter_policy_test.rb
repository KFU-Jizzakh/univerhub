require "test_helper"

class Reporting::ReporterPolicyTest < ActiveSupport::TestCase
  setup do
    @admin           = users(:admin_user)
    @supervisor      = users(:supervisor_user)
    @visitor         = users(:visitor_user)
    @manager         = users(:manager_user)
    @reporter        = users(:reporter_user)
    @reporting_admin = users(:reporting_admin_user)
  end

  def policy(user)
    Reporting::ReporterPolicy.new(user, :reporter)
  end

  test "index? allowed for visitor, admin, supervisor, reporting.admin" do
    [ @admin, @supervisor, @visitor, @reporting_admin ].each { |u| assert policy(u).index? }
  end

  test "index? denied for manager and reporter" do
    [ @manager, @reporter ].each { |u| assert_not policy(u).index? }
  end

  test "show? delegates to index?" do
    assert policy(@admin).show?
    assert policy(@reporting_admin).show?
    assert_not policy(@manager).show?
  end
end
