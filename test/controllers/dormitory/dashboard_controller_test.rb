require "test_helper"

class Dormitory::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @commandant = users(:dormitory_commandant_user)
    @registrar = users(:dormitory_registrar_user)
    @regular_user = users(:visitor_user)
  end

  test "admin can access dashboard" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success
  end

  test "commandant can access dashboard" do
    sign_in_as @commandant
    get dormitory_dashboard_path
    assert_response :success
  end

  test "registrar can access dashboard" do
    sign_in_as @registrar
    get dormitory_dashboard_path
    assert_response :success
  end

  test "regular user cannot access dashboard" do
    sign_in_as @regular_user
    get dormitory_dashboard_path
    assert_redirected_to root_path
  end

  test "dashboard calculates metrics correctly" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select "h1", text: "Дашборд общежития"
    assert_select ".card", minimum: 6
  end

  test "dashboard shows total beds metric" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card", text: /Всего мест/ do
      assert_select ".h2", text: /\A\d+\z/
    end
  end

  test "dashboard shows total debt metric" do
    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card .text-muted", text: "Общий долг"
  end

  test "dashboard shows total paid metric for the active year" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update!(required_amount: 10000)
    receipt = acc.receipts.build(amount: 4000, paid_at: Date.current)
    receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    receipt.save!

    paid_resident = Dormitory::Resident.create!(
      last_name: "Иванова", first_name: "Мария", gender: :female, course: 1,
      date_of_birth: "2000-01-01", student_ticket_number: "ТЕСТ-ОПЛ", status: :not_settled
    )
    paid = Dormitory::Accommodation.new(
      resident: paid_resident, room: dormitory_rooms(:room_101),
      application_number: "З-ОПЛ", contract_number: "Д-ОПЛ",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      required_amount: 10000
    )
    paid.save!
    paid_receipt = paid.receipts.build(amount: 10000, paid_at: Date.current)
    paid_receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    paid_receipt.save!

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card", text: /Всего оплачено/ do
      assert_select ".h2", text: "14 000,00"
    end
  end

  test "dashboard total paid excludes accommodations of other academic years" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update!(required_amount: 10000)
    receipt = acc.receipts.build(amount: 4000, paid_at: Date.current)
    receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    receipt.save!

    other_resident = Dormitory::Resident.create!(
      last_name: "Сидоров", first_name: "Олег", gender: :male, course: 1,
      date_of_birth: "2000-01-01", student_ticket_number: "ТЕСТ-ГОД", status: :not_settled
    )
    other = Dormitory::Accommodation.new(
      resident: other_resident, room: dormitory_rooms(:room_101_building_two),
      application_number: "З-ГОД", contract_number: "Д-ГОД",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      academic_year: dormitory_academic_years(:pending_year_2026_2027)
    )
    other.save!
    other_receipt = other.receipts.build(amount: 7000, paid_at: Date.current)
    other_receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    other_receipt.save!

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card", text: /Всего оплачено/ do
      assert_select ".h2", text: "4 000,00"
    end
  end

  test "dashboard total paid is zero without an active academic year" do
    Dormitory::AcademicYear.active.update_all(status: :pending)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card", text: /Всего оплачено/ do
      assert_select ".h2", text: "0,00"
    end
  end

  test "dashboard total paid is scoped to commandant buildings" do
    own = dormitory_accommodations(:active_accommodation)
    own.update!(required_amount: 10000)
    own_receipt = own.receipts.build(amount: 4000, paid_at: Date.current)
    own_receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    own_receipt.save!

    other_resident = Dormitory::Resident.create!(
      last_name: "Козлов", first_name: "Пётр", gender: :male, course: 1,
      date_of_birth: "2000-01-01", student_ticket_number: "ТЕСТ-ДБ", status: :not_settled
    )
    other = Dormitory::Accommodation.new(
      resident: other_resident, room: dormitory_rooms(:room_101_building_two),
      application_number: "З-ДБ", contract_number: "Д-ДБ",
      start_date: Date.current, planned_end_date: Date.current + 1.year,
      required_amount: 10000
    )
    other.save!
    other_receipt = other.receipts.build(amount: 7000, paid_at: Date.current)
    other_receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    other_receipt.save!

    dormitory_commandant_buildings(:commandant_building_two).update!(deactivated_at: Time.current)

    sign_in_as @commandant
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card", text: /Всего оплачено/ do
      assert_select ".h2", text: "4 000,00"
    end
    assert_not_includes response.body, "7 000,00"
  end

  test "dashboard shows debt by building when debt exists" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update!(status: :active, required_amount: 10000)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success

    assert_select ".card-header", text: "Долг по корпусам"
  end

  test "dashboard excludes discarded accommodations from overdue list" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update_columns(planned_end_date: Date.current - 1.day)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success
    assert_includes @response.body, acc.resident.full_name

    acc.update_columns(discarded_at: Time.current)
    get dormitory_dashboard_path
    assert_response :success
    assert_not_includes @response.body, acc.resident.full_name
  end

  test "dashboard excludes discarded accommodations from debt calculation" do
    acc = dormitory_accommodations(:active_accommodation)
    acc.update!(required_amount: 10000)

    sign_in_as @admin
    get dormitory_dashboard_path
    assert_response :success
    assert_select ".card-header", text: "Долг по корпусам", count: 1

    acc.update_columns(discarded_at: Time.current)
    get dormitory_dashboard_path
    assert_response :success
    assert_select ".card-header", text: "Долг по корпусам", count: 0
  end
end
