require "test_helper"

class Dormitory::ViolationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @manager = users(:manager_user)
    @resident = dormitory_residents(:resident_two_settled)
    @violation = dormitory_violations(:violation_open_noise)
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "index requires auth" do
    get dormitory_violations_path
    assert_redirected_to new_session_path
  end

  test "index denied for manager" do
    sign_in_as @manager
    get dormitory_violations_path
    assert_redirected_to root_path
  end

  test "index allowed for admin" do
    sign_in_as @admin
    get dormitory_violations_path
    assert_response :success
  end

  test "index allowed for dormitory_admin" do
    sign_in_as @dormitory_admin
    get dormitory_violations_path
    assert_response :success
  end

  test "index allowed for commandant" do
    sign_in_as @commandant
    get dormitory_violations_path
    assert_response :success
  end

  test "show requires auth" do
    get dormitory_violation_path(@violation)
    assert_redirected_to new_session_path
  end

  test "show allowed for admin" do
    sign_in_as @admin
    get dormitory_violation_path(@violation)
    assert_response :success
  end

  test "new requires auth" do
    get new_dormitory_violation_path
    assert_redirected_to new_session_path
  end

  test "new allowed for admin" do
    sign_in_as @admin
    get new_dormitory_violation_path
    assert_response :success
  end

  test "create violation with valid params" do
    sign_in_as @admin
    assert_difference "Dormitory::Violation.count", 1 do
      post dormitory_violations_path, params: {
        dormitory_violation: {
          resident_id: @resident.id,
          violation_type: "noise",
          occurred_at: Time.current,
          place: "Комната 201",
          description: "Громкая музыка после 23:00",
          status: "open"
        }
      }
    end
    assert_redirected_to dormitory_violation_path(Dormitory::Violation.last)
    assert_equal I18n.t("dormitory.violations.created"), flash[:notice]
  end

  test "create violation with invalid params" do
    sign_in_as @admin
    assert_no_difference "Dormitory::Violation.count" do
      post dormitory_violations_path, params: {
        dormitory_violation: {
          resident_id: @resident.id,
          violation_type: "noise"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "edit allowed for admin" do
    sign_in_as @admin
    get edit_dormitory_violation_path(@violation)
    assert_response :success
  end

  test "update violation with valid params" do
    sign_in_as @admin
    patch dormitory_violation_path(@violation), params: {
      dormitory_violation: {
        place: "Новое место",
        description: @violation.description
      }
    }
    assert_redirected_to dormitory_violation_path(@violation)
    assert_equal I18n.t("dormitory.violations.updated"), flash[:notice]
    @violation.reload
    assert_equal "Новое место", @violation.place
  end

  test "update violation with invalid params" do
    sign_in_as @admin
    patch dormitory_violation_path(@violation), params: {
      dormitory_violation: {
        place: "",
        description: ""
      }
    }
    assert_response :unprocessable_entity
  end

  test "destroy violation" do
    sign_in_as @admin
    assert_difference "Dormitory::Violation.kept.count", -1 do
      delete dormitory_violation_path(@violation)
    end
    assert_redirected_to dormitory_violations_path
    assert_equal I18n.t("dormitory.violations.destroyed"), flash[:notice]
  end

  test "create denied for manager" do
    sign_in_as @manager
    assert_no_difference "Dormitory::Violation.count" do
      post dormitory_violations_path, params: {
        dormitory_violation: {
          resident_id: @resident.id,
          violation_type: "noise",
          occurred_at: Time.current,
          place: "Комната 201",
          description: "Громкая музыка",
          status: "open"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "destroy denied for manager" do
    sign_in_as @manager
    assert_no_difference "Dormitory::Violation.kept.count" do
      delete dormitory_violation_path(@violation)
    end
    assert_redirected_to root_path
  end
end
