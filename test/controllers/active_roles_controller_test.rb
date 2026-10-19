require "test_helper"

class ActiveRolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dual = users(:admin_user)
    @dual.user_roles.create!(role_name: "dormitory.commandant")
  end

  test "update switches the active role of the current session" do
    sign_in_as @dual
    assert_nil Current.session.reload.active_role
    assert_equal "admin", Current.session.user.effective_role

    patch active_role_path, params: { role_name: "dormitory.commandant" }

    assert_redirected_to root_path
    assert_equal "dormitory.commandant", Current.session.reload.active_role
    assert_not_nil flash[:notice]
  end

  test "update does not touch other sessions of the same user" do
    other_session = @dual.sessions.create!(active_role: "admin")

    sign_in_as @dual, active_role: "admin"
    patch active_role_path, params: { role_name: "dormitory.commandant" }

    assert_redirected_to root_path
    assert_equal "dormitory.commandant", Current.session.reload.active_role
    assert_equal "admin", other_session.reload.active_role
  end

  test "update rejects a role that is not assigned to the user" do
    sign_in_as @dual, active_role: "admin"

    assert_no_changes -> { Current.session.reload.active_role } do
      patch active_role_path, params: { role_name: "reporting.manager" }
    end

    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "update rejects an unknown role name" do
    sign_in_as @dual, active_role: "admin"

    assert_no_changes -> { Current.session.reload.active_role } do
      patch active_role_path, params: { role_name: "superadmin" }
    end

    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end
end
