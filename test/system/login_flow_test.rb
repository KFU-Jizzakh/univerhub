require "application_system_test_case"

class LoginFlowTest < ApplicationSystemTestCase
  test "user can log in with valid credentials" do
    visit new_session_path
    fill_in "Email", with: users(:admin_user).email_address
    fill_in "Пароль", with: "password"
    click_on "Войти"

    assert_current_path root_path
  end

  test "invalid credentials keep user on login page" do
    visit new_session_path
    fill_in "Email", with: users(:admin_user).email_address
    fill_in "Пароль", with: "wrong"
    click_on "Войти"

    assert_current_path new_session_path
  end
end
