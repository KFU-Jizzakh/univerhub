require "application_system_test_case"

module Dormitory
  class ResidentsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_user)
    end

    def sign_in_as_admin
      visit new_session_path
      fill_in "Email", with: @admin.email_address
      fill_in "Пароль", with: "password"
      click_on "Войти"
    end

    def register_resident_with_placement(ticket)
      visit new_dormitory_resident_path
      fill_in "Фамилия", with: "Новый"
      fill_in "Имя", with: "Студент"
      select "Мужской", from: "dormitory_resident_gender"
      select "2", from: "dormitory_resident_course"
      fill_in "Дата рождения", with: "2003-01-01"
      fill_in "Студбилет", with: ticket
      fill_in "Номер заявления", with: "З-СИС"
      fill_in "Номер договора", with: "Д-СИС"

      page.attach_file("dormitory_resident_application_file", Rails.root.join("test/fixtures/files/test.pdf"), make_visible: true)
      page.attach_file("dormitory_resident_contract_file", Rails.root.join("test/fixtures/files/test.pdf"), make_visible: true)

      click_on "Создать"

      Dormitory::Resident.find_by(student_ticket_number: ticket)
    end

    def assert_select_value(selector, expected)
      page.document.synchronize do
        assert_equal expected.to_s, find(selector).value
      end
    end

    test "admin registers resident with prefilled place and sees pending accommodation" do
      sign_in_as_admin
      resident = register_resident_with_placement("SYS001")

      assert_current_path dormitory_resident_path(resident)
      assert_text "Ожидает"
      assert_no_text "Выселить"
    end

    test "registration form prefills the next free room and bed" do
      sign_in_as_admin
      visit new_dormitory_resident_path

      select "Мужской", from: "dormitory_resident_gender"
      select "2", from: "dormitory_resident_course"

      assert_select_value "#placement_room_id", dormitory_rooms(:room_201).id
      assert_select_value "#placement_bed_label", "B"
    end

    test "registration form highlights invalid fields after submit" do
      sign_in_as_admin
      visit new_dormitory_resident_path
      fill_in "Email", with: "not-an-email"
      click_on "Создать"

      assert_selector "#dormitory_resident_email.is-invalid"
      assert_selector ".invalid-feedback", text: "неверный формат email"
    end

    test "admin edits pending accommodation and current room and bed stay pre-selected" do
      sign_in_as_admin
      resident = register_resident_with_placement("SYS002")
      acc = resident.accommodations.kept.last

      assert_equal "pending", acc.status
      room_id = acc.room_id
      bed_label = acc.bed_label
      assert bed_label.present?

      visit edit_dormitory_accommodation_path(acc)

      assert_select_value "#dormitory_accommodation_room_id", room_id
      assert_select_value "#dormitory_accommodation_bed_label", bed_label

      fill_in "Комментарий", with: "проверка предвыбора"
      click_on "Сохранить"

      assert_current_path dormitory_accommodation_path(acc)
      assert_equal room_id, acc.reload.room_id
      assert_equal bed_label, acc.bed_label
      assert_equal "pending", acc.status
    end
  end
end
