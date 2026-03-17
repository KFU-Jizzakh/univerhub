require "application_system_test_case"

module Dormitory
  class AccommodationsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_user)
      @resident = dormitory_residents(:resident_one_not_settled)
    end

    test "admin navigates to check-in form and sees all fields" do
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"

      visit dormitory_resident_path(@resident)
      click_on "Заселить"

      assert_current_path new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_selector "h2", text: "Заселение проживающего"
      assert_field "Номер заявления"
      assert_field "Номер договора"
      assert_field "Дата заселения"
      assert_selector "select#building_id"
      assert_selector "select#dormitory_accommodation_room_id"
      assert_field "Комментарий"
      assert_button "Подтвердить"
    end

    test "check-in form re-renders on incomplete submission" do
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"

      visit new_dormitory_accommodation_path(resident_id: @resident.id)
      click_on "Подтвердить"

      assert_equal 422, page.status_code
      assert_selector "h2", text: "Заселение проживающего"
    end
  end
end
