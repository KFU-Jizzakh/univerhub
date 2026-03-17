require "test_helper"

class UserRoleTest < ActiveSupport::TestCase
  setup do
    @user = users(:manager_user)
    @role = roles(:reporting_manager)
    Current.session = @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  test "valid with unique user and role" do
    user = users(:manager_user)
    role = roles(:reporting_reporter)
    user_role = UserRole.new(user: user, role: role)
    assert user_role.valid?
  end

  test "invalid with duplicate user and role" do
    existing = user_roles(:manager_role)
    user_role = UserRole.new(user: existing.user, role: existing.role)
    assert_not user_role.valid?
    assert_includes user_role.errors[:role_id], "уже занят"
  end

  test "do_create! creates UserRole and OutboxEvent" do
    user = User.create!(email_address: "test@example.com", password: "password")
    role = roles(:reporting_visitor)
    user_role = UserRole.new(user: user, role: role)

    assert_difference "UserRole.count", 1 do
      assert_difference "OutboxEvent.count", 1 do
        user_role.do_create!
      end
    end

    event = OutboxEvent.last
    assert_equal "user_role.created", event.action
    assert_instance_of UserRole, event.record
  end

  test "do_update! updates UserRole and creates OutboxEvent" do
    user_role = user_roles(:manager_role)
    new_role = roles(:reporting_visitor)

    assert_difference "OutboxEvent.count", 1 do
      user_role.do_update!(role_id: new_role.id)
    end

    assert_equal new_role, user_role.reload.role
    assert_equal "user_role.updated", OutboxEvent.last.action
  end

  test "do_destroy! destroys UserRole and creates OutboxEvent" do
    user_role = user_roles(:manager_role)

    assert_difference "UserRole.count", -1 do
      assert_difference "OutboxEvent.count", 1 do
        user_role.do_destroy!
      end
    end

    assert_equal "user_role.destroyed", OutboxEvent.last.action
  end
end
