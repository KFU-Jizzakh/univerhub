require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "create with deactivated user credentials redirects to login with error" do
    @user.update!(deactivated_at: Time.current)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_equal I18n.t("sessions.deactivated"), flash[:alert]
  end

  test "deactivated user with active session is logged out and redirected" do
    sign_in_as(@user)
    @user.update!(deactivated_at: Time.current)

    get root_path

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.deactivated"), flash[:alert]
    assert_empty cookies[:session_id]
  end
end
