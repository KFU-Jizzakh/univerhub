require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "rejects malformed email" do
    user = User.new(email_address: "not-an-email", password: "password", password_confirmation: "password")
    assert_not user.valid?
    assert_predicate user.errors[:email_address], :any?
  end

  test "accepts valid email format" do
    user = User.new(email_address: "ok@example.com", password: "password", password_confirmation: "password")
    assert user.valid?, user.errors.full_messages.inspect
  end

  test "requires minimum 8 char password on create" do
    user = User.new(email_address: "short@example.com", password: "abc", password_confirmation: "abc")
    assert_not user.valid?
    assert_predicate user.errors[:password], :any?
  end

  test "update without password does not trigger password length validation" do
    user = User.create!(email_address: "user@example.com", password: "password", password_confirmation: "password")
    user.email_address = "renamed@example.com"
    assert user.valid?
    assert user.save
  end

  test "active? returns true for user without deactivated_at" do
    user = User.new(deactivated_at: nil)
    assert user.active?
    assert_not user.deactivated?
  end

  test "deactivated? returns true for user with deactivated_at" do
    user = User.new(deactivated_at: Time.current)
    assert user.deactivated?
    assert_not user.active?
  end

  test "deactivate! sets deactivated_at to current time" do
    user = User.create!(email_address: "deactivate@test.local", password: "password", password_confirmation: "password")
    assert_nil user.deactivated_at

    freeze_time do
      user.deactivate!
      assert_equal Time.current, user.deactivated_at
    end
  end

  test "activate! clears deactivated_at" do
    user = User.create!(email_address: "activate@test.local", password: "password", password_confirmation: "password", deactivated_at: Time.current)
    assert user.deactivated?

    user.activate!
    assert_nil user.deactivated_at
    assert user.active?
  end

  test "active scope returns only active users" do
    active_user = User.create!(email_address: "active_scope@test.local", password: "password", password_confirmation: "password")
    deactivated_user = User.create!(email_address: "deactivated_scope@test.local", password: "password", password_confirmation: "password", deactivated_at: Time.current)

    assert_includes User.active, active_user
    assert_not_includes User.active, deactivated_user
  end

  test "deactivated scope returns only deactivated users" do
    active_user = User.create!(email_address: "active_scope2@test.local", password: "password", password_confirmation: "password")
    deactivated_user = User.create!(email_address: "deactivated_scope2@test.local", password: "password", password_confirmation: "password", deactivated_at: Time.current)

    assert_includes User.deactivated, deactivated_user
    assert_not_includes User.deactivated, active_user
  end

  test "discard! sets discarded_at and terminates sessions" do
    user = User.create!(email_address: "discard@test.local", password: "password", password_confirmation: "password")
    user.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    assert_not user.discarded?
    assert_equal 1, user.sessions.count

    user.discard!

    assert user.discarded?
    assert_equal 0, user.sessions.count
  end

  test "kept scope excludes discarded users" do
    kept_user = User.create!(email_address: "kept@test.local", password: "password", password_confirmation: "password")
    discarded_user = User.create!(email_address: "discarded@test.local", password: "password", password_confirmation: "password")
    discarded_user.discard!

    assert_includes User.kept, kept_user
    assert_not_includes User.kept, discarded_user
  end

  test "last_active_with_role? returns true when user is the only active with role" do
    dorm_admin = users(:dormitory_admin_user)
    assert User.last_active_with_role?(dorm_admin, "dormitory.admin")
  end

  test "last_active_with_role? returns false when multiple active users with role" do
    dorm_admin = users(:dormitory_admin_user)
    second = User.create!(email_address: "second_role@test.local", password: "password123", password_confirmation: "password123")
    second.roles << Role.find_by(name: "dormitory.admin")

    assert_not User.last_active_with_role?(dorm_admin, "dormitory.admin")
  end

  test "last_active_with_role? returns false when user does not have the role" do
    reporter = users(:reporter_user)
    assert_not User.last_active_with_role?(reporter, "dormitory.admin")
  end
end
