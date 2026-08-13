require "test_helper"

module Dormitory
  class AccommodationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin_user)
      @dormitory_admin = users(:dormitory_admin_user)
      @commandant = users(:dormitory_commandant_user)
      @registrar = users(:dormitory_registrar_user)
      @plain_user = users(:reporter_user)
      @resident = dormitory_residents(:resident_one_not_settled)
      @room = dormitory_rooms(:room_101)
      @building = dormitory_buildings(:building_one)
    end

    def sign_in(user)
      post session_path, params: { email_address: user.email_address, password: "password" }
    end

    def file_upload(filename = "test.pdf", content_type = "application/pdf")
      Rack::Test::UploadedFile.new(
        file_fixture_path.join(filename),
        content_type
      )
    end

    def file_fixture_path
      Rails.root.join("test/fixtures/files")
    end

    def settle_params(overrides = {})
      {
        dormitory_accommodation: {
          resident_id: @resident.id,
          room_id: @room.id,
          application_number: "З-001",
          contract_number: "Д-001",
          start_date: Date.current,
          planned_end_date: Date.current + 1.year,
          application_file: file_upload,
          contract_file: file_upload
        }.merge(overrides)
      }
    end

    # --- new ---

    test "admin sees settle form" do
      sign_in @admin
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_response :success
    end

    test "dormitory admin sees settle form" do
      sign_in @dormitory_admin
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_response :success
    end

    test "commandant sees settle form" do
      sign_in @commandant
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_response :success
    end

    test "settle form prefills documents from resident" do
      @resident.update!(application_number: "З-100", contract_number: "Д-100")
      @resident.application_file.attach(
        io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
      )
      @resident.contract_file.attach(
        io: StringIO.new("cnt"), filename: "contract.pdf", content_type: "application/pdf"
      )

      sign_in @commandant
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_response :success
      assert_includes response.body, "З-100"
      assert_includes response.body, "Д-100"
      assert_includes response.body, "app.pdf"
      assert_includes response.body, "contract.pdf"
    end

    test "commandant settles resident using documents prepared by registrar" do
      @resident.update!(application_number: "З-200", contract_number: "Д-200")
      @resident.application_file.attach(
        io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
      )
      @resident.contract_file.attach(
        io: StringIO.new("cnt"), filename: "contract.pdf", content_type: "application/pdf"
      )

      sign_in @commandant
      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params(
          application_number: "З-200", contract_number: "Д-200",
          application_file: nil, contract_file: nil
        )
      end

      accommodation = Accommodation.last
      assert_redirected_to dormitory_resident_path(@resident)
      assert accommodation.application_file.attached?
      assert accommodation.contract_file.attached?
      assert_equal "app.pdf", accommodation.application_file.filename.to_s
      assert_equal "contract.pdf", accommodation.contract_file.filename.to_s
    end

    test "settlement files uploaded in form take precedence over resident documents" do
      @resident.update!(application_number: "З-300", contract_number: "Д-300")
      @resident.application_file.attach(
        io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
      )

      sign_in @commandant
      post dormitory_accommodations_path, params: settle_params

      accommodation = Accommodation.last
      assert_equal "test.pdf", accommodation.application_file.filename.to_s
    end

    test "settlement without files anywhere fails with files_required" do
      sign_in @commandant
      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params(
          application_file: nil, contract_file: nil
        )
      end
      assert_response :unprocessable_entity
      assert_match "Необходимо прикрепить все документы.", response.body
    end

    test "settlement copies numbers from resident card when form sends blank values" do
      @resident.update!(application_number: "З-400", contract_number: "Д-400")
      @resident.application_file.attach(
        io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
      )
      @resident.contract_file.attach(
        io: StringIO.new("cnt"), filename: "contract.pdf", content_type: "application/pdf"
      )

      sign_in @commandant
      post dormitory_accommodations_path, params: settle_params(
        application_number: "", contract_number: "",
        application_file: nil, contract_file: nil
      )

      accommodation = Accommodation.last
      assert_redirected_to dormitory_resident_path(@resident)
      assert_equal "З-400", accommodation.application_number
      assert_equal "Д-400", accommodation.contract_number
    end

    test "settlement form does not prefill documents when resident already has accommodations" do
      Dormitory::Accommodation.create!(
        resident: @resident,
        room: @room,
        application_number: "З-OLD",
        contract_number: "Д-OLD",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year
      )
      @resident.update!(application_number: "З-500", contract_number: "Д-500")
      @resident.application_file.attach(
        io: StringIO.new("app"), filename: "app.pdf", content_type: "application/pdf"
      )

      sign_in @commandant
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_response :success
      assert_not_includes response.body, "З-500"
      assert_not_includes response.body, "app.pdf"
    end

    test "settlement does not copy documents when resident already has accommodations" do
      Dormitory::Accommodation.create!(
        resident: @resident,
        room: @room,
        application_number: "З-OLD",
        contract_number: "Д-OLD",
        start_date: Date.current,
        planned_end_date: Date.current + 1.year
      )
      @resident.update!(application_number: "З-600", contract_number: "Д-600")

      sign_in @commandant
      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params(
          application_number: "", contract_number: "",
          application_file: nil, contract_file: nil
        )
      end
      assert_response :unprocessable_entity
    end

    test "registrar cannot access settle form" do
      sign_in @registrar
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_redirected_to root_path
    end

    test "plain user cannot access settle form" do
      sign_in @plain_user
      get new_dormitory_accommodation_path(resident_id: @resident.id)
      assert_redirected_to root_path
    end

    # --- create ---

    test "admin settles resident successfully" do
      sign_in @admin

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params
      end

      assert_redirected_to dormitory_resident_path(@resident)
      follow_redirect!
      assert_includes response.body, "заселён"
    end

    test "settle updates resident status to settled" do
      sign_in @admin
      post dormitory_accommodations_path, params: settle_params

      assert_equal "settled", @resident.reload.status
      assert_equal @room.id, @resident.current_room_id
    end

    test "settle updates room occupancy" do
      sign_in @admin
      post dormitory_accommodations_path, params: settle_params

      assert_equal 1, @room.reload.current_occupancy
    end

    test "dormitory admin settles resident" do
      sign_in @dormitory_admin

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params
      end
    end

    test "commandant settles resident in assigned building" do
      sign_in @commandant

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params
      end
    end

    test "plain user cannot settle" do
      sign_in @plain_user

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params
      end
    end

    test "settling already-settled resident fails" do
      @resident.update!(status: :settled, current_room: @room)
      sign_in @admin

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params
      end

      assert_response :unprocessable_entity
    end

    test "settling into full room fails without force" do
      @room.update_columns(current_occupancy: @room.capacity, status: :fully_occupied)
      sign_in @admin

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params
      end

      assert_response :unprocessable_entity
    end

    test "admin force settles into full room" do
      @room.update_columns(current_occupancy: @room.capacity, status: :fully_occupied)
      sign_in @admin

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params.merge(force: "1")
      end

      assert_equal "overcrowded", @room.reload.status
    end

    test "commandant cannot force settle" do
      @room.update_columns(current_occupancy: @room.capacity, status: :fully_occupied)
      sign_in @commandant

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params.merge(force: "1")
      end
    end

    test "missing files returns unprocessable" do
      sign_in @admin

      params = {
        dormitory_accommodation: {
          resident_id: @resident.id,
          room_id: @room.id,
          application_number: "З-001",
          contract_number: "Д-001",
          start_date: Date.current
        }
      }

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: params
      end

      assert_response :unprocessable_entity
    end

    test "form preserves data on error" do
      sign_in @admin
      post dormitory_accommodations_path, params: {
        dormitory_accommodation: {
          resident_id: @resident.id,
          room_id: nil,
          application_number: "З-001",
          contract_number: "Д-001",
          start_date: Date.current,
          application_file: file_upload,
          contract_file: file_upload
        }
      }

      assert_response :unprocessable_entity
      assert_includes response.body, "З-001"
    end

    test "settling with gender conflict fails" do
      @room.update_column(:gender_restriction, :female)
      sign_in @admin

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: settle_params
      end

      assert_response :unprocessable_entity
    end

    test "force settle into partially occupied room" do
      @room.update_columns(current_occupancy: 1, status: :partially_occupied)
      sign_in @admin

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params.merge(force: "1")
      end

      @room.reload
      assert_equal 2, @room.current_occupancy
      assert_equal "partially_occupied", @room.status
    end

    # --- index ---

    test "admin sees accommodations index" do
      sign_in @admin
      get dormitory_accommodations_path
      assert_response :success
    end

    test "commandant sees accommodations index" do
      sign_in @commandant
      get dormitory_accommodations_path
      assert_response :success
    end

    test "plain user cannot access accommodations index" do
      sign_in @plain_user
      get dormitory_accommodations_path
      assert_redirected_to root_path
    end

    test "index filters by building" do
      sign_in @admin
      get dormitory_accommodations_path, params: { building_id: @building.id }
      assert_response :success
    end

    test "index filters by status" do
      sign_in @admin
      get dormitory_accommodations_path, params: { status: "active" }
      assert_response :success
    end

    # --- show ---

    test "admin sees accommodation show" do
      sign_in @admin
      acc = create_accommodation
      get dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "commandant sees accommodation show in assigned building" do
      sign_in @commandant
      acc = create_accommodation
      get dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "plain user cannot access accommodation show" do
      sign_in @plain_user
      acc = create_accommodation
      get dormitory_accommodation_path(acc)
      assert_redirected_to root_path
    end

    # --- edit ---

    test "admin gets edit form" do
      sign_in @admin
      acc = create_accommodation
      get edit_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "commandant gets edit form in assigned building" do
      sign_in @commandant
      acc = create_accommodation
      get edit_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "plain user cannot access edit form" do
      sign_in @plain_user
      acc = create_accommodation
      get edit_dormitory_accommodation_path(acc)
      assert_redirected_to root_path
    end

    # --- update ---

    test "admin updates accommodation" do
      sign_in @admin
      acc = create_accommodation

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { application_number: "З-002" }
      }

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal "З-002", acc.reload.application_number
    end

    test "commandant updates accommodation in assigned building" do
      sign_in @commandant
      acc = create_accommodation

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { application_number: "З-003" }
      }

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal "З-003", acc.reload.application_number
    end

    test "update preserves resident_id" do
      sign_in @admin
      acc = create_accommodation

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { application_number: "З-004" }
      }

      acc.reload
      assert_equal @resident.id, acc.resident_id
    end

    test "plain user cannot update accommodation" do
      sign_in @plain_user
      acc = create_accommodation

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { application_number: "З-005" }
      }

      assert_redirected_to root_path
    end

    private

    def create_accommodation
      post dormitory_accommodations_path, params: settle_params
      Accommodation.last
    end

    def transfer_params(acc, target_room, overrides = {})
      {
        dormitory_accommodation: {
          room_id: target_room.id,
          application_number: "З-ТР001",
          contract_number: "Д-ТР001",
          start_date: Date.current,
          planned_end_date: Date.current + 1.year,
          eviction_reason: "transfer",
          application_file: file_upload,
          contract_file: file_upload
        }.merge(overrides)
      }
    end

    # --- new_transfer ---

    test "admin sees transfer form for active accommodation" do
      sign_in @admin
      acc = create_accommodation
      get new_transfer_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "dormitory admin sees transfer form" do
      sign_in @dormitory_admin
      acc = create_accommodation
      get new_transfer_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "commandant sees transfer form in assigned building" do
      sign_in @commandant
      acc = create_accommodation
      get new_transfer_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "plain user cannot access transfer form" do
      sign_in @plain_user
      acc = create_accommodation
      get new_transfer_dormitory_accommodation_path(acc)
      assert_redirected_to root_path
    end

    test "transfer form redirects for non-active accommodation" do
      sign_in @admin
      acc = create_accommodation
      acc.update_column(:status, :completed)
      get new_transfer_dormitory_accommodation_path(acc)
      assert_redirected_to dormitory_accommodation_path(acc)
    end

    # --- transfer ---

    test "admin transfers resident successfully" do
      sign_in @admin
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)

      assert_difference -> { Accommodation.count }, 1 do
        patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room)
      end

      assert_redirected_to dormitory_resident_path(@resident)
      follow_redirect!
      assert_includes response.body, "переселён"
    end

    test "transfer completes old accommodation" do
      sign_in @admin
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)

      patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room)

      acc.reload
      assert_equal "completed", acc.status
      assert_equal "transfer", acc.eviction_reason
      assert_equal Date.current, acc.actual_end_date
    end

    test "transfer updates resident current room and building" do
      sign_in @admin
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)

      patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room)

      @resident.reload
      assert_equal target_room.id, @resident.current_room_id
    end

    test "transfer updates both room occupancies" do
      sign_in @admin
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)
      original_room = acc.room

      patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room)

      assert_equal 0, original_room.reload.current_occupancy
      assert_equal 1, target_room.reload.current_occupancy
    end

    test "commandant transfers resident in assigned building" do
      sign_in @commandant
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)

      assert_difference -> { Accommodation.count }, 1 do
        patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room)
      end
    end

    test "plain user cannot transfer" do
      sign_in @plain_user
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)

      assert_no_difference -> { Accommodation.count } do
        patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room)
      end
    end

    test "transfer with validation error re-renders form" do
      sign_in @admin
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)

      patch transfer_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: {
          room_id: target_room.id,
          application_number: "",
          contract_number: "",
          start_date: Date.current,
          eviction_reason: "transfer"
        }
      }

      assert_response :unprocessable_entity
    end

    test "transfer with repair eviction reason" do
      sign_in @admin
      acc = create_accommodation
      target_room = dormitory_rooms(:room_102)
      original_room = acc.room

      patch transfer_dormitory_accommodation_path(acc), params: transfer_params(acc, target_room, eviction_reason: "repair")

      assert_redirected_to dormitory_resident_path(@resident)
      assert_equal "free", original_room.reload.status
    end

    # --- new_eviction ---

    test "admin sees eviction form for active accommodation" do
      sign_in @admin
      acc = create_accommodation
      get new_eviction_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "dormitory admin sees eviction form" do
      sign_in @dormitory_admin
      acc = create_accommodation
      get new_eviction_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "commandant sees eviction form in assigned building" do
      sign_in @commandant
      acc = create_accommodation
      get new_eviction_dormitory_accommodation_path(acc)
      assert_response :success
    end

    test "plain user cannot access eviction form" do
      sign_in @plain_user
      acc = create_accommodation
      get new_eviction_dormitory_accommodation_path(acc)
      assert_redirected_to root_path
    end

    test "eviction form redirects for non-active accommodation" do
      sign_in @admin
      acc = create_accommodation
      acc.update_column(:status, :completed)
      get new_eviction_dormitory_accommodation_path(acc)
      assert_redirected_to dormitory_accommodation_path(acc)
    end

    # --- evict ---

    test "admin evicts resident successfully" do
      sign_in @admin
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "graduation" }
      }

      assert_redirected_to dormitory_resident_path(@resident)
      follow_redirect!
      assert_includes response.body, "выселен"
    end

    test "evict completes accommodation" do
      sign_in @admin
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "graduation" }
      }

      acc.reload
      assert_equal "completed", acc.status
      assert_equal "graduation", acc.eviction_reason
      assert_equal Date.current, acc.actual_end_date
    end

    test "evict updates resident status to evicted" do
      sign_in @admin
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "graduation" }
      }

      @resident.reload
      assert_equal "evicted", @resident.status
      assert_nil @resident.current_room_id
    end

    test "evict decreases room occupancy" do
      sign_in @admin
      acc = create_accommodation
      original_room = acc.room

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "graduation" }
      }

      assert_equal 0, original_room.reload.current_occupancy
    end

    test "evict with comment updates comment" do
      sign_in @admin
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "voluntary", comment: "Уехал" }
      }

      assert_equal "Уехал", acc.reload.comment
    end

    test "commandant evicts resident in assigned building" do
      sign_in @commandant
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "graduation" }
      }

      assert_redirected_to dormitory_resident_path(@resident)
    end

    test "plain user cannot evict" do
      sign_in @plain_user
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "graduation" }
      }

      assert_redirected_to root_path
    end

    test "evict with validation error re-renders form" do
      sign_in @admin
      acc = create_accommodation

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "other", comment: "" }
      }

      assert_response :unprocessable_entity
    end

    test "evict with repair reason frees the room" do
      sign_in @admin
      acc = create_accommodation
      original_room = acc.room
      original_room.update_columns(current_occupancy: 1, capacity: 1, status: :fully_occupied)

      patch evict_dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { eviction_reason: "repair" }
      }

      assert_equal "free", original_room.reload.status
    end

    # --- SPEC-DORM-09: Payment fields in settlement ---

    def settle_params_with_amount(overrides = {})
      {
        dormitory_accommodation: {
          resident_id: @resident.id,
          room_id: @room.id,
          application_number: "З-001",
          contract_number: "Д-001",
          start_date: Date.current,
          planned_end_date: Date.current + 1.year,
          application_file: file_upload,
          contract_file: file_upload,
          required_amount: 12000
        }.deep_merge(overrides)
      }
    end

    test "create settles with required_amount" do
      sign_in @admin

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params_with_amount
      end

      acc = Accommodation.kept.last
      assert_equal 12000, acc.required_amount
      assert_redirected_to dormitory_resident_path(@resident)
    end

    test "create settles without receipt" do
      sign_in @admin

      assert_difference -> { Accommodation.count }, 1 do
        post dormitory_accommodations_path, params: settle_params_with_amount
      end
      assert_redirected_to dormitory_resident_path(@resident)
    end

    test "edit honors required_amount" do
      acc = create_accommodation
      sign_in @admin

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: {
          required_amount: 15000,
          start_date: acc.start_date,
          planned_end_date: acc.planned_end_date
        }
      }

      assert_equal 15000, acc.reload.required_amount
      assert_redirected_to dormitory_accommodation_path(acc)
    end

    # --- SPEC-DORM-12: pending registration flow ---

    def create_pending_accommodation
      acc = Accommodation.new(
        resident: @resident, room: @room,
        application_number: "З-ПЕНД", contract_number: "Д-ПЕНД",
        start_date: Date.current, planned_end_date: Date.current + 1.year
      )
      acc.application_file.attach(io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf")
      acc.contract_file.attach(io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf")
      acc.do_register!
      acc
    end

    test "admin confirms pending accommodation" do
      acc = create_pending_accommodation
      sign_in @admin

      post confirm_dormitory_accommodation_path(acc)

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal "active", acc.reload.status
      assert_equal "settled", @resident.reload.status
      assert_equal @room.id, @resident.current_room_id
    end

    test "registrar confirms pending accommodation" do
      acc = create_pending_accommodation
      sign_in @registrar

      post confirm_dormitory_accommodation_path(acc)

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal "active", acc.reload.status
      assert_equal "settled", @resident.reload.status
      assert_equal @room.id, @resident.current_room_id
    end

    test "registrar cannot reject pending accommodation" do
      acc = create_pending_accommodation
      sign_in @registrar

      post reject_dormitory_accommodation_path(acc)

      assert_redirected_to root_path
      assert_equal "pending", acc.reload.status
    end

    test "commandant cannot confirm pending accommodation" do
      acc = create_pending_accommodation
      sign_in @commandant

      post confirm_dormitory_accommodation_path(acc)

      assert_redirected_to root_path
      assert_equal "pending", acc.reload.status
    end

    test "admin rejects pending accommodation and releases place" do
      acc = create_pending_accommodation
      sign_in @admin

      post reject_dormitory_accommodation_path(acc)

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal "cancelled", acc.reload.status
      assert_equal "not_settled", @resident.reload.status
      assert_equal 0, @room.reload.current_occupancy
    end

    test "commandant cannot reject pending accommodation" do
      acc = create_pending_accommodation
      sign_in @commandant

      post reject_dormitory_accommodation_path(acc)

      assert_redirected_to root_path
      assert_equal "pending", acc.reload.status
    end

    test "admin cannot reject pending accommodation with future start_date" do
      acc = Accommodation.new(
        resident: @resident, room: @room,
        application_number: "З-ПЕНД", contract_number: "Д-ПЕНД",
        start_date: Date.current + 1.month, planned_end_date: Date.current + 1.year
      )
      acc.application_file.attach(io: StringIO.new("test"), filename: "app.pdf", content_type: "application/pdf")
      acc.contract_file.attach(io: StringIO.new("test"), filename: "contract.pdf", content_type: "application/pdf")
      acc.do_register!
      sign_in @admin

      post reject_dormitory_accommodation_path(acc)

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal "pending", acc.reload.status
      assert_equal 1, @room.reload.current_occupancy
      assert_nil OutboxEvent.find_by(action: "dormitory.accommodation.rejected")
    end

    test "admin updates pending accommodation room via edit" do
      acc = create_pending_accommodation
      target_room = dormitory_rooms(:room_102)
      sign_in @admin

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: {
          room_id: target_room.id,
          application_number: "З-ПЕНД", contract_number: "Д-ПЕНД",
          start_date: Date.current, planned_end_date: Date.current + 1.year
        }
      }

      assert_redirected_to dormitory_accommodation_path(acc)
      assert_equal target_room.id, acc.reload.room_id
      assert_equal 0, @room.reload.current_occupancy
      assert_equal 1, target_room.reload.current_occupancy
    end

    test "admin cannot move pending accommodation to a gender-conflicting room" do
      acc = create_pending_accommodation
      target_room = dormitory_rooms(:room_102)
      target_room.update_column(:gender_restriction, :female)
      sign_in @admin

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: {
          room_id: target_room.id,
          application_number: "З-ПЕНД", contract_number: "Д-ПЕНД",
          start_date: Date.current, planned_end_date: Date.current + 1.year
        }
      }

      assert_response :unprocessable_entity
      assert_includes response.body, I18n.t("activerecord.errors.models.dormitory/accommodation.attributes.room.gender_conflict")
      assert_equal @room.id, acc.reload.room_id
      assert_equal 1, @room.reload.current_occupancy
      assert_equal 0, target_room.reload.current_occupancy
    end

    test "commandant cannot edit pending accommodation" do
      acc = create_pending_accommodation
      sign_in @commandant

      patch dormitory_accommodation_path(acc), params: {
        dormitory_accommodation: { application_number: "З-ХАК" }
      }

      assert_redirected_to root_path
      assert_equal "pending", acc.reload.status
    end

    test "show renders pending accommodation" do
      acc = create_pending_accommodation
      sign_in @admin

      get dormitory_accommodation_path(acc)

      assert_response :success
    end

    test "show renders the payment block for a pending accommodation" do
      acc = create_pending_accommodation
      receipt = acc.receipts.build(amount: 5000, paid_at: Date.current)
      receipt.attachment.attach(
        io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
      )
      receipt.do_create!
      sign_in @admin

      get dormitory_accommodation_path(acc)

      assert_response :success
      assert_includes response.body, I18n.t("views.dormitory.accommodations.section_payments")
      assert_includes response.body, "5 000,00"
      assert_includes response.body, I18n.t("views.dormitory.accommodations.add_receipt")
    end
  end
end
