require "test_helper"

class Dormitory::BatchEvictionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @academic_year = dormitory_academic_years(:active_year_2025_2026)
    @building = dormitory_buildings(:building_one)
    @room_101 = dormitory_rooms(:room_101)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def settle_resident(name:)
    resident = Dormitory::Resident.create!(
      last_name: name, first_name: "Тест", gender: :male,
      date_of_birth: 20.years.ago,
      student_ticket_number: "BATCHCTL#{SecureRandom.hex(4)}"
    )
    acc = Dormitory::Accommodation.new(
      resident: resident, room: @room_101,
      application_number: "BC-#{SecureRandom.hex(3)}",
      contract_number: "CC-#{SecureRandom.hex(3)}",
      start_date: Date.current, planned_end_date: Date.current + 1.year
    )
    acc.application_file.attach(
      io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf"
    )
    acc.contract_file.attach(
      io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf"
    )
    acc.receipts.build(
      amount: 10000, paid_at: Date.current,
      attachment: { io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf" }
    )
    Current.session = @admin.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    acc.do_settle!
    resident
  end

  test "admin sees batch operations index" do
    sign_in @admin
    get dormitory_batch_evictions_path
    assert_response :success
  end

  test "admin sees new batch operation form" do
    sign_in @admin
    get new_dormitory_batch_eviction_path
    assert_response :success
    assert_includes response.body, @building.name
  end

  test "redirects when no active year" do
    Dormitory::AcademicYear.active.update_all(status: :closed)
    sign_in @admin
    get new_dormitory_batch_eviction_path
    assert_redirected_to dormitory_dashboard_path
    # Restore
    Dormitory::AcademicYear.active.update_all(status: :active)
  end

  test "admin performs mass eviction" do
    r1 = settle_resident(name: "Тестов")
    r2 = settle_resident(name: "Проверкин")

    sign_in @admin
    assert_difference -> { Dormitory::BatchOperation.count }, 1 do
      post dormitory_batch_evictions_path, params: {
        building_id: @building.id,
        resident_ids: [ r1.id, r2.id ],
        eviction_reason: "graduation",
        comment: "Test mass eviction"
      }
    end

    assert_redirected_to dormitory_batch_eviction_path(Dormitory::BatchOperation.last)
    assert_equal "evicted", r1.reload.status
    assert_equal "evicted", r2.reload.status
  end

  test "admin sees batch operation results" do
    r1 = settle_resident(name: "Экспортов")
    sign_in @admin
    post dormitory_batch_evictions_path, params: {
      building_id: @building.id,
      resident_ids: [ r1.id ],
      eviction_reason: "voluntary"
    }
    op = Dormitory::BatchOperation.last
    get dormitory_batch_eviction_path(op)
    assert_response :success
    assert_includes response.body, op.total_count.to_s
  end

  test "shows error when no residents selected" do
    sign_in @admin
    post dormitory_batch_evictions_path, params: {
      building_id: @building.id,
      resident_ids: [],
      eviction_reason: "graduation"
    }
    assert_response :unprocessable_entity
  end
end
