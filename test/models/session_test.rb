require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "valid with active_role from NAMES" do
    session = Session.new(user: users(:admin_user), active_role: "admin")

    assert session.valid?
  end

  test "valid without active_role" do
    session = Session.new(user: users(:admin_user))

    assert session.valid?
  end

  test "invalid with active_role outside NAMES" do
    session = Session.new(user: users(:admin_user), active_role: "superadmin")

    assert_not session.valid?
  end
end
