require "test_helper"

class Dormitory::ReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @commandant = users(:dormitory_commandant_user)
    @plain_user = users(:reporter_user)
    @accommodation = dormitory_accommodations(:active_accommodation)
    @accommodation.update!(status: :active)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def file_upload(filename = "test.pdf", content_type = "application/pdf")
    Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files", filename),
      content_type
    )
  end

  def receipt_params(overrides = {})
    {
      dormitory_receipt: {
        amount: 5000,
        paid_at: Date.current,
        attachment: file_upload
      }.merge(overrides)
    }
  end

  # --- new ---

  test "admin sees new receipt form" do
    sign_in @admin
    get new_dormitory_accommodation_receipt_path(@accommodation)
    assert_response :success
  end

  test "plain user cannot access new receipt form" do
    sign_in @plain_user
    get new_dormitory_accommodation_receipt_path(@accommodation)
    assert_redirected_to root_path
  end

  # --- create ---

  test "admin creates receipt successfully" do
    sign_in @admin

    assert_difference -> { Dormitory::Receipt.kept.count }, 1 do
      post dormitory_accommodation_receipts_path(@accommodation), params: receipt_params
    end

    assert_redirected_to dormitory_accommodation_path(@accommodation)
    follow_redirect!
    assert_includes response.body, "Квитанция добавлена"
  end

  test "create receipt sets amount and paid_at" do
    sign_in @admin
    post dormitory_accommodation_receipts_path(@accommodation), params: receipt_params

    receipt = Dormitory::Receipt.kept.last
    assert_equal 5000, receipt.amount
    assert_equal Date.current, receipt.paid_at
  end

  test "create receipt with validation error" do
    sign_in @admin
    post dormitory_accommodation_receipts_path(@accommodation),
         params: { dormitory_receipt: { amount: "-5", paid_at: Date.current, attachment: file_upload } }

    assert_response :unprocessable_entity
  end

  test "create receipt on non-active accommodation redirects" do
    @accommodation.update_columns(status: "completed")
    sign_in @admin

    assert_no_difference -> { Dormitory::Receipt.kept.count } do
      post dormitory_accommodation_receipts_path(@accommodation), params: receipt_params
    end

    assert_redirected_to dormitory_accommodation_path(@accommodation)
    assert_equal flash[:alert], I18n.t("dormitory.accommodations.not_active")
  end

  # --- edit ---

  test "admin sees edit receipt form" do
    sign_in @admin
    receipt = create_receipt

    get edit_dormitory_accommodation_receipt_path(@accommodation, receipt)
    assert_response :success
  end

  # --- update ---

  test "admin updates receipt successfully" do
    sign_in @admin
    receipt = create_receipt

    patch dormitory_accommodation_receipt_path(@accommodation, receipt),
          params: { dormitory_receipt: { amount: 7000, paid_at: Date.current } }

    assert_redirected_to dormitory_accommodation_path(@accommodation)
    assert_equal 7000, receipt.reload.amount
  end

  test "update receipt with validation error" do
    sign_in @admin
    receipt = create_receipt

    patch dormitory_accommodation_receipt_path(@accommodation, receipt),
          params: { dormitory_receipt: { amount: 0, paid_at: Date.current } }

    assert_response :unprocessable_entity
  end

  # --- destroy ---

  test "admin destroys receipt (soft-delete)" do
    sign_in @admin
    receipt = create_receipt

    assert_difference -> { Dormitory::Receipt.kept.count }, -1 do
      delete dormitory_accommodation_receipt_path(@accommodation, receipt)
    end

    assert_redirected_to dormitory_accommodation_path(@accommodation)
    assert receipt.reload.discarded?
    follow_redirect!
    assert_includes response.body, "Квитанция удалена"
  end

  # --- Authorization ---

  test "commandant creates receipt in assigned building" do
    sign_in @commandant
    assert_difference -> { Dormitory::Receipt.kept.count }, 1 do
      post dormitory_accommodation_receipts_path(@accommodation), params: receipt_params
    end
    assert_redirected_to dormitory_accommodation_path(@accommodation)
  end

  test "commandant cannot create receipt in unassigned building" do
    Dormitory::CommandantBuilding.active.where(user: @commandant).destroy_all
    Dormitory::CommandantBuilding.create!(
      user: @commandant, building: dormitory_buildings(:building_two)
    )
    sign_in @commandant

    assert_no_difference -> { Dormitory::Receipt.kept.count } do
      post dormitory_accommodation_receipts_path(@accommodation), params: receipt_params
    end
    assert_redirected_to root_path
  end

  test "plain user cannot create receipt" do
    sign_in @plain_user
    assert_no_difference -> { Dormitory::Receipt.kept.count } do
      post dormitory_accommodation_receipts_path(@accommodation), params: receipt_params
    end
    assert_redirected_to root_path
  end

  test "plain user cannot edit receipt" do
    sign_in @plain_user
    receipt = create_receipt
    get edit_dormitory_accommodation_receipt_path(@accommodation, receipt)
    assert_redirected_to root_path
  end

  test "plain user cannot destroy receipt" do
    sign_in @plain_user
    receipt = create_receipt

    assert_no_difference -> { Dormitory::Receipt.kept.count } do
      delete dormitory_accommodation_receipt_path(@accommodation, receipt)
    end
    assert_redirected_to root_path
  end

  private

  def create_receipt
    receipt = @accommodation.receipts.build(amount: 5000, paid_at: Date.current)
    receipt.attachment.attach(
      io: StringIO.new("test"), filename: "receipt.pdf", content_type: "application/pdf"
    )
    receipt.do_create!
    receipt
  end
end
