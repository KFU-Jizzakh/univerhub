require "application_system_test_case"

class ReportCreationTest < ApplicationSystemTestCase
  test "report_manager can create a report end-to-end" do
    visit new_session_path
    fill_in "Email", with: users(:manager_user).email_address
    fill_in "Пароль", with: "password"
    click_on "Войти"
    assert_current_path root_path

    visit new_reporting_report_path
    fill_in "Название", with: "System Test Report"
    fill_in "Описание", with: "Проверка потока создания"
    select users(:reporter_user).email_address, from: "Исполнитель"
    select users(:reviewer_user).email_address, from: "Проверяющий"

    assert_difference "Reporting::Report.count", 1 do
      click_on "Создать"
    end
    assert_text "System Test Report"
  end
end
