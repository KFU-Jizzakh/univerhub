require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in_as(@admin)
  end

  test "create with invalid role_names renders new with errors" do
    post admin_users_path, params: {
      user: {
        email_address: "newuser@test.local",
        password: "password",
        password_confirmation: "password",
        role_names: [ "hacker" ]
      }
    }

    assert_response :unprocessable_entity
    assert_match I18n.t("admin.users.invalid_role_names"), response.body
  end

  test "create with duplicate role_names renders new with errors" do
    assert_no_difference "User.count" do
      post admin_users_path, params: {
        user: {
          email_address: "dup@test.local",
          password: "password",
          password_confirmation: "password",
          role_names: [ "reporting.reporter", "reporting.reporter" ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match I18n.t("admin.users.invalid_role_names"), response.body
  end

  test "update with duplicate role_names renders edit with errors" do
    user = users(:reporter_user)
    original_role_names = user.role_names.sort

    patch admin_user_path(user), params: {
      user: {
        email_address: user.email_address,
        role_names: [ "reporting.reporter", "reporting.reporter" ]
      }
    }

    assert_response :unprocessable_entity
    assert_match I18n.t("admin.users.invalid_role_names"), response.body
    assert_equal original_role_names, user.reload.role_names.sort
  end

  test "activate sets deactivated_at to nil" do
    user = users(:reporter_user)
    user.update!(deactivated_at: Time.current)
    assert user.deactivated?

    patch activate_admin_user_path(user)

    assert_redirected_to admin_user_path(user)
    assert user.reload.active?
  end

  test "deactivate sets deactivated_at to current time" do
    user = users(:reporter_user)
    assert user.active?

    freeze_time do
      patch deactivate_admin_user_path(user)

      assert_redirected_to admin_user_path(user)
      assert user.reload.deactivated?
      assert_equal Time.current, user.deactivated_at
    end
  end

  test "cannot deactivate self" do
    patch deactivate_admin_user_path(@admin)

    assert_response :redirect
    assert @admin.reload.active?
  end

  test "cannot activate self" do
    @admin.update!(deactivated_at: Time.current)

    patch activate_admin_user_path(@admin)

    assert_response :redirect
    assert @admin.reload.deactivated?
  end

  # ── reporting.admin tests ────────────────────────────────────

  test "reporting.admin can access users index" do
    sign_in_as(users(:reporting_admin_user))
    get admin_users_path
    assert_response :success
  end

  test "reporting.admin can create user with reporting roles" do
    sign_in_as(users(:reporting_admin_user))

    post admin_users_path, params: {
      user: {
        email_address: "new_reporter@test.local",
        password: "password",
        password_confirmation: "password",
        role_names: [ "reporting.reporter" ]
      }
    }

    assert_redirected_to admin_user_path(User.find_by(email_address: "new_reporter@test.local"))
  end

  test "reporting.admin cannot create user with non-reporting roles" do
    sign_in_as(users(:reporting_admin_user))

    post admin_users_path, params: {
      user: {
        email_address: "new_admin@test.local",
        password: "password",
        password_confirmation: "password",
        role_names: [ "admin" ]
      }
    }

    assert_response :unprocessable_entity
    assert_match I18n.t("admin.users.invalid_role_names"), response.body
  end

  test "reporting.admin can deactivate reporting-only user" do
    sign_in_as(users(:reporting_admin_user))
    user = users(:reporter_user)
    assert user.active?

    patch deactivate_admin_user_path(user)

    assert_redirected_to admin_user_path(user)
    assert user.reload.deactivated?
  end

  test "reporting.admin cannot deactivate admin user" do
    sign_in_as(users(:reporting_admin_user))

    patch deactivate_admin_user_path(@admin)

    assert_response :redirect
    assert @admin.reload.active?
  end

  test "reporting.admin sees only reporting roles in new form" do
    sign_in_as(users(:reporting_admin_user))
    get new_admin_user_path
    assert_response :success
    assert_select "label", text: "reporting.reporter"
    assert_select "label", text: "admin", count: 0
    assert_select "label", text: "supervisor", count: 0
  end

  test "reporting.admin sees only reporting roles in edit form" do
    sign_in_as(users(:reporting_admin_user))
    get edit_admin_user_path(users(:reporter_user))
    assert_response :success
    assert_select "label", text: "reporting.reporter"
    assert_select "label", text: "admin", count: 0
    assert_select "label", text: "supervisor", count: 0
  end

  test "reporting.admin sees only reporting users in index" do
    sign_in_as(users(:reporting_admin_user))
    get admin_users_path
    assert_response :success
    assert_select "td", text: users(:reporter_user).email_address
    assert_select "td", text: @admin.email_address, count: 0
  end

  test "create with profile creates OutboxEvent" do
    sign_in_as(@admin)

    assert_difference "OutboxEvent.count", 1 do
      post admin_users_path, params: {
        user: {
          email_address: "profiled@test.local",
          password: "password",
          password_confirmation: "password",
          first_name: "Иван",
          last_name: "Иванов"
        }
      }
    end

    new_user = User.find_by(email_address: "profiled@test.local")
    assert_equal "user_profile.created", OutboxEvent.last.action
    assert_equal new_user.profile, OutboxEvent.last.record
  end

  test "update with profile changes creates OutboxEvent" do
    user = users(:reporter_user)
    user.create_profile!(last_name: "Старый")

    assert_difference "OutboxEvent.count", 1 do
      patch admin_user_path(user), params: {
        user: {
          email_address: user.email_address,
          first_name: "Новое",
          last_name: "Новый",
          role_names: [ "reporting.reporter" ]
        }
      }
    end

    assert_equal "user_profile.updated", OutboxEvent.last.action
  end

  # ── dormitory.admin tests ────────────────────────────────────

  test "dormitory.admin can create user with registrar role" do
    sign_in_as(users(:dormitory_admin_user))

    post admin_users_path, params: {
      user: {
        email_address: "new_registrar@test.local",
        password: "password",
        password_confirmation: "password",
        role_names: [ "dormitory.registrar" ]
      }
    }

    assert_redirected_to admin_user_path(User.find_by(email_address: "new_registrar@test.local"))
  end

  test "dormitory.admin sees only dormitory roles in new form" do
    sign_in_as(users(:dormitory_admin_user))
    get new_admin_user_path
    assert_response :success
    assert_select "label", text: "dormitory.registrar"
    assert_select "label", text: "dormitory.commandant"
    assert_select "label", text: "reporting.reporter", count: 0
  end

  test "dormitory.admin sees registrar in users index" do
    sign_in_as(users(:dormitory_admin_user))
    get admin_users_path
    assert_response :success
    assert_select "td", text: users(:dormitory_registrar_user).email_address
  end
end
