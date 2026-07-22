require "test_helper"

module Dormitory
  class AccommodationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin_user)
      @dormitory_admin = users(:dormitory_admin_user)
      @commandant = users(:dormitory_commandant_user)
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
          contract_file: file_upload,
          payment_receipt: file_upload
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
          contract_file: file_upload,
          payment_receipt: file_upload
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
          contract_file: file_upload,
          payment_receipt: file_upload
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

    def settle_params_with_receipt(overrides = {})
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
          required_amount: 12000,
          receipts_attributes: {
            "0" => {
              amount: 12000,
              paid_at: Date.current,
              attachment: file_upload
            }
          }
        }.deep_merge(overrides)
      }
    end

    test "create settles with required_amount and nested receipt" do
      sign_in @admin

      assert_difference -> { Accommodation.count }, 1 do
        assert_difference -> { Dormitory::Receipt.kept.count }, 1 do
          post dormitory_accommodations_path, params: settle_params_with_receipt
        end
      end

      acc = Accommodation.kept.last
      assert_equal 12000, acc.required_amount
      assert_equal 12000, acc.total_paid
      assert_redirected_to dormitory_resident_path(@resident)
    end

    test "create fails when receipt without file" do
      sign_in @admin

      params = settle_params_with_receipt
      params[:dormitory_accommodation][:receipts_attributes]["0"].delete(:attachment)

      assert_no_difference -> { Accommodation.count } do
        post dormitory_accommodations_path, params: params
      end
      assert_response :unprocessable_entity
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
  end
end
