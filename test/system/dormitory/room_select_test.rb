require "application_system_test_case"

module Dormitory
  # Единственный JS-тест выбора комнат: остальной системный набор работает на rack_test без JS
  class RoomSelectTest < ApplicationSystemTestCase
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

    setup do
      skip "headless Chrome is not available" unless chrome_available?

      @admin = users(:admin_user)
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"
      assert_no_field "Пароль", wait: 10 # ждём завершения Turbo-редиректа после входа
    end

    test "transfer form loads rooms, explains empty list and fills free beds" do
      acc = dormitory_accommodations(:active_accommodation) # проживающая: женский пол, курс 2
      room = dormitory_rooms(:room_101_building_two)        # свободна, без ограничений

      visit new_transfer_dormitory_accommodation_path(acc)

      select "Корпус 2", from: "building_id"
      assert_selector "#dormitory_accommodation_room_id option[value='#{room.id}']"
      assert_no_selector "#dormitory_accommodation_room_id option[disabled]"

      select "#{room.number} (этаж #{room.floor}, свободно 2)", from: "dormitory_accommodation_room_id"
      assert_selector "#dormitory_accommodation_bed_label option", count: 3 # подсказка + A + B

      # в Корпусе 1 мест, подходящих проживающей, нет: все комнаты мужские и занятые
      Dormitory::Room.kept.where(building: dormitory_buildings(:building_one)).each do |r|
        r.update_columns(gender_restriction: 0, status: "fully_occupied", current_occupancy: r.capacity)
      end

      select "Корпус 1", from: "building_id"
      assert_selector "#dormitory_accommodation_room_id option[disabled]",
                      text: "Нет свободных мест, подходящих проживающему (пол/курс)"
      assert_no_selector "#dormitory_accommodation_room_id option[value='#{room.id}']"
    end

    private

    def chrome_available?
      %w[google-chrome chromium chromium-browser].any? do |bin|
        system("which #{bin} > /dev/null 2>&1")
      end
    end
  end
end
