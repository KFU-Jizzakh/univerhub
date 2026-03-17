require "test_helper"

class Admin::UserPolicyTest < ActiveSupport::TestCase
  setup do
    @admin           = users(:admin_user)
    @manager         = users(:manager_user)
    @reporter        = users(:reporter_user)
    @reporting_admin = users(:reporting_admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant      = users(:dormitory_commandant_user)
  end

  def policy(user, record)
    Admin::UserPolicy.new(user, record)
  end

  test "index?, show?, new?, create?, edit?, update? require admin" do
    %i[index? show? new? create? edit? update?].each do |p|
      assert policy(@admin, @reporter).public_send(p), "expected #{p} true for admin"
      assert_not policy(@manager, @reporter).public_send(p), "expected #{p} false for non-admin"
    end
  end

  test "index?, show?, new?, create?, edit?, update? allowed for reporting.admin" do
    %i[index? show? new? create? edit? update?].each do |p|
      assert policy(@reporting_admin, @reporter).public_send(p), "expected #{p} true for reporting.admin"
    end
  end

  test "activate? allowed for admin on other users" do
    assert policy(@admin, @reporter).activate?
  end

  test "activate? denied when admin targets self" do
    assert_not policy(@admin, @admin).activate?
  end

  test "activate? denied for non-admin" do
    assert_not policy(@manager, @reporter).activate?
  end

  test "activate? allowed for reporting.admin on reporting-only user" do
    assert policy(@reporting_admin, @reporter).activate?
  end

  test "activate? denied for reporting.admin on admin user" do
    assert_not policy(@reporting_admin, @admin).activate?
  end

  test "activate? denied for reporting.admin on self" do
    assert_not policy(@reporting_admin, @reporting_admin).activate?
  end

  test "deactivate? allowed for admin on other users" do
    assert policy(@admin, @reporter).deactivate?
  end

  test "deactivate? denied when admin targets self" do
    assert_not policy(@admin, @admin).deactivate?
  end

  test "deactivate? denied for non-admin" do
    assert_not policy(@manager, @reporter).deactivate?
  end

  test "deactivate? allowed for reporting.admin on reporting-only user" do
    assert policy(@reporting_admin, @reporter).deactivate?
  end

  test "deactivate? denied for reporting.admin on admin user" do
    assert_not policy(@reporting_admin, @admin).deactivate?
  end

  test "deactivate? denied for reporting.admin on self" do
    assert_not policy(@reporting_admin, @reporting_admin).deactivate?
  end

  test "index?, show?, new?, create?, edit?, update? allowed for dormitory.admin" do
    %i[index? show? new? create? edit? update?].each do |p|
      assert policy(@dormitory_admin, @commandant).public_send(p), "expected #{p} true for dormitory.admin"
    end
  end

  test "activate? allowed for dormitory.admin on commandant" do
    assert policy(@dormitory_admin, @commandant).activate?
  end

  test "activate? denied for dormitory.admin on admin user" do
    assert_not policy(@dormitory_admin, @admin).activate?
  end

  test "activate? denied for dormitory.admin on reporting user" do
    assert_not policy(@dormitory_admin, @reporter).activate?
  end

  test "activate? denied for dormitory.admin on self" do
    assert_not policy(@dormitory_admin, @dormitory_admin).activate?
  end

  test "deactivate? allowed for dormitory.admin on commandant" do
    assert policy(@dormitory_admin, @commandant).deactivate?
  end

  test "deactivate? denied for dormitory.admin on admin user" do
    assert_not policy(@dormitory_admin, @admin).deactivate?
  end

  test "deactivate? denied for dormitory.admin on self" do
    assert_not policy(@dormitory_admin, @dormitory_admin).deactivate?
  end

  test "destroy? allowed for admin on other users" do
    assert policy(@admin, @reporter).destroy?
  end

  test "destroy? denied when admin targets self" do
    assert_not policy(@admin, @admin).destroy?
  end

  test "destroy? denied for non-admin" do
    assert_not policy(@manager, @reporter).destroy?
  end

  test "destroy? denied for reporting.admin" do
    assert_not policy(@reporting_admin, @reporter).destroy?
  end

  test "destroy? denied for last active dormitory.admin" do
    assert_not policy(@admin, @dormitory_admin).destroy?
  end

  test "destroy? allowed when multiple dormitory.admin exist" do
    second_admin = User.create!(email_address: "second_dorm_admin@test.local", password: "password123", password_confirmation: "password123")
    second_admin.roles << Role.find_by(name: "dormitory.admin")
    assert policy(@admin, @dormitory_admin).destroy?
  end

  test "deactivate? denied for last active dormitory.admin" do
    assert_not policy(@admin, @dormitory_admin).deactivate?
  end

  test "deactivate? allowed when multiple dormitory.admin exist" do
    second_admin = User.create!(email_address: "second_dorm_admin2@test.local", password: "password123", password_confirmation: "password123")
    second_admin.roles << Role.find_by(name: "dormitory.admin")
    assert policy(@admin, @dormitory_admin).deactivate?
  end

  test "reset_password? allowed for admin on other users" do
    assert policy(@admin, @reporter).reset_password?
  end

  test "reset_password? denied when admin targets self" do
    assert_not policy(@admin, @admin).reset_password?
  end

  test "reset_password? denied for non-admin" do
    assert_not policy(@manager, @reporter).reset_password?
  end
end
