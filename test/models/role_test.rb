require "test_helper"

class RoleTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  test "fixture roles are valid" do
    assert roles(:admin).valid?
  end

  test "invalid without name" do
    role = Role.new
    assert_not role.valid?
    assert_includes role.errors[:name], "не может быть пустым"
  end

  test "invalid with duplicate name" do
    role = Role.new(name: "admin")
    assert_not role.valid?
    assert_includes role.errors[:name], "уже занят"
  end

  test "invalid with name not in NAMES" do
    role = Role.new(name: "hacker")
    assert_not role.valid?
    assert_includes role.errors[:name], "имеет неверное значение"
  end

  test "do_create! creates Role and OutboxEvent" do
    Role.where(name: "reporting.visitor").destroy_all
    role = Role.new(name: "reporting.visitor")

    assert_difference "Role.count", 1 do
      assert_difference "OutboxEvent.count", 1 do
        role.do_create!
      end
    end

    assert_equal "role.created", OutboxEvent.last.action
    assert_equal role, OutboxEvent.last.record
  end

  test "do_update! updates Role and creates OutboxEvent" do
    Role.where(name: "supervisor").destroy_all
    role = roles(:reporting_visitor)

    assert_difference "OutboxEvent.count", 1 do
      role.do_update!(name: "supervisor")
    end

    assert_equal "supervisor", role.reload.name
    assert_equal "role.updated", OutboxEvent.last.action
  end

  test "do_destroy! destroys Role and creates OutboxEvent" do
    role = roles(:reporting_visitor)

    assert_difference "Role.count", -1 do
      assert_difference "OutboxEvent.count", 1 do
        role.do_destroy!
      end
    end

    assert_equal "role.destroyed", OutboxEvent.last.action
  end
end
