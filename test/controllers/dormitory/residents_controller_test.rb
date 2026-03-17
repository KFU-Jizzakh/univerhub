require "test_helper"

class Dormitory::ResidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @building = dormitory_buildings(:building_one)
    @building_two = dormitory_buildings(:building_two)
    @resident = dormitory_residents(:resident_one_not_settled)
    @settled_resident = dormitory_residents(:resident_two_settled)

    @unassigned_building = Dormitory::Building.create!(
      name: "Неassignовый корпус", address: "ул. Новая, 9", floors_count: 2,
    )
    @room_unassigned = Dormitory::Room.create!(
      number: "999", building: @unassigned_building, floor: 1, capacity: 2,
    )
    @resident_unassigned = Dormitory::Resident.create!(
      last_name: "Чужой", first_name: "Человек", gender: :male,
      date_of_birth: 20.years.ago, student_ticket_number: "UNASSIGNED2",
    )
    # Settle the unassigned resident so the commandant restriction applies via current_room
    acc = Dormitory::Accommodation.new(
      resident: @resident_unassigned,
      room: @room_unassigned,
      application_number: "APP-999",
      contract_number: "CNT-999",
      start_date: Date.current,
      planned_end_date: Date.current + 1.year,
    )
    acc.application_file.attach(
      io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf",
    )
    acc.contract_file.attach(
      io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf",
    )
    acc.payment_receipt.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf",
    )
    acc.do_settle!
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "index requires auth" do
    get dormitory_residents_path
    assert_redirected_to new_session_path
  end

  test "index denied for manager" do
    sign_in_as @manager
    get dormitory_residents_path
    assert_redirected_to root_path
  end

  test "index renders for admin" do
    sign_in_as @admin
    get dormitory_residents_path
    assert_response :success
  end

  test "index renders for dormitory.admin" do
    sign_in_as @dormitory_admin
    get dormitory_residents_path
    assert_response :success
  end

  test "index renders for commandant" do
    sign_in_as @commandant
    get dormitory_residents_path
    assert_response :success
  end

  test "index filters by status" do
    sign_in_as @admin
    get dormitory_residents_path, params: { status: "not_settled" }
    assert_response :success
  end

  test "index filters by gender" do
    sign_in_as @admin
    get dormitory_residents_path, params: { gender: "male" }
    assert_response :success
  end

  test "index searches by name" do
    sign_in_as @admin
    get dormitory_residents_path, params: { query: "Иванов" }
    assert_response :success
  end

  test "commandant sees only assigned buildings" do
    sign_in_as @commandant
    get dormitory_residents_path
    assert_response :success
  end

  test "show renders" do
    sign_in_as @admin
    get dormitory_resident_path(@resident)
    assert_response :success
  end

  test "show denied for commandant from unassigned building" do
    sign_in_as @commandant
    get dormitory_resident_path(@resident_unassigned)
    assert_redirected_to root_path
  end

  test "new renders" do
    sign_in_as @admin
    get new_dormitory_resident_path
    assert_response :success
  end

  test "create resident with valid params" do
    sign_in_as @admin
    assert_difference "Dormitory::Resident.count", 1 do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW001"
        }
      }
    end
    assert_redirected_to dormitory_resident_path(Dormitory::Resident.last)
    assert_equal I18n.t("dormitory.residents.created"), flash[:notice]
  end

  test "create resident with duplicate student_ticket fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.count" do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male",
          date_of_birth: "2000-01-01",
          student_ticket_number: @resident.student_ticket_number
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "create resident as commandant" do
    sign_in_as @commandant
    assert_difference "Dormitory::Resident.count", 1 do
      post dormitory_residents_path, params: {
        dormitory_resident: {
          last_name: "Новый", first_name: "Человек", gender: "male",
          date_of_birth: "2000-01-01", student_ticket_number: "NEW002"
        }
      }
    end
  end

  test "edit renders" do
    sign_in_as @admin
    get edit_dormitory_resident_path(@resident)
    assert_response :success
  end

  test "update resident with valid params" do
    sign_in_as @admin
    patch dormitory_resident_path(@resident), params: {
      dormitory_resident: { phone: "+79111111111" }
    }
    assert_redirected_to dormitory_resident_path(@resident)
    assert_equal "+79111111111", @resident.reload.phone
  end

  test "update gender for settled resident fails" do
    sign_in_as @admin
    patch dormitory_resident_path(@settled_resident), params: {
      dormitory_resident: { gender: "male" }
    }
    assert_response :unprocessable_entity
  end

  test "destroy not_settled resident" do
    sign_in_as @admin
    assert_difference "Dormitory::Resident.kept.count", -1 do
      delete dormitory_resident_path(@resident)
    end
    assert_redirected_to dormitory_residents_path
    assert @resident.reload.discarded?
  end

  test "destroy evicted resident" do
    evicted = dormitory_residents(:resident_three_evicted)
    sign_in_as @admin
    assert_difference "Dormitory::Resident.kept.count", -1 do
      delete dormitory_resident_path(evicted)
    end
  end

  test "destroy settled resident fails" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Resident.kept.count" do
      delete dormitory_resident_path(@settled_resident)
    end
    assert_redirected_to dormitory_resident_path(@settled_resident)
  end

  test "destroy denied for commandant" do
    sign_in_as @commandant
    assert_no_difference "Dormitory::Resident.kept.count" do
      delete dormitory_resident_path(@resident)
    end
    assert_redirected_to root_path
  end

  test "check_ticket returns found" do
    sign_in_as @admin
    get check_ticket_dormitory_residents_path, params: { number: @resident.student_ticket_number }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["found"]
    assert_equal @resident.id, json["id"]
    assert_equal @resident.full_name, json["full_name"]
  end

  test "check_ticket returns not found" do
    sign_in_as @admin
    get check_ticket_dormitory_residents_path, params: { number: "NOTEXIST" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["found"]
  end

  test "check_ticket denied for manager" do
    sign_in_as @manager
    get check_ticket_dormitory_residents_path, params: { number: "123" }, as: :json
    assert_redirected_to root_path
  end
end
