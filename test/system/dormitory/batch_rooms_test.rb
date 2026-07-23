require "application_system_test_case"

module Dormitory
  class BatchRoomsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_user)
      @building = dormitory_buildings(:building_one)
    end

    test "admin sees batch rooms form with all fields" do
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"

      visit new_dormitory_batch_room_path

      assert_selector "h1", text: I18n.t("views.dormitory.batch_rooms.page_title")
      assert_selector "[data-controller='batch-rooms']"
      assert_selector "select#building_id"
      assert_selector "input[data-batch-rooms-target='floor']"
      assert_selector "input[data-batch-rooms-target='startNumber']"
      assert_selector "input[data-batch-rooms-target='endNumber']"
      assert_selector "input[data-batch-rooms-target='defaultCapacity']"
      assert_button I18n.t("views.dormitory.batch_rooms.generate")
    end

    test "batch rooms form includes all stimulustargets" do
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"

      visit new_dormitory_batch_room_path

      assert_selector "[data-batch-rooms-target='building']"
      assert_selector "[data-batch-rooms-target='floor']"
      assert_selector "[data-batch-rooms-target='startNumber']"
      assert_selector "[data-batch-rooms-target='endNumber']"
      assert_selector "[data-batch-rooms-target='defaultCapacity']"
      assert_selector "[data-batch-rooms-target='defaultGender']"
      assert_selector "[data-batch-rooms-target='tableCard'].d-none"
      assert_selector "[data-batch-rooms-target='tableBody']"
      assert_selector "[data-batch-rooms-target='hiddenFields']"
      assert_selector "[data-batch-rooms-target='submitBtn']"
      assert_selector "[data-batch-rooms-target='countBadge']"
    end

    test "batch rooms form pre-selects building from query param" do
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"

      visit new_dormitory_batch_room_path(building_id: @building.id)

      assert_selector "select option[selected]", text: @building.name
    end
  end
end
