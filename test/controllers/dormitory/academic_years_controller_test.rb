require "test_helper"

class Dormitory::AcademicYearsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @dormitory_admin = users(:dormitory_admin_user)
    @commandant = users(:dormitory_commandant_user)
    @year = dormitory_academic_years(:active_year_2025_2026)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  test "admin sees index" do
    sign_in @admin
    get dormitory_academic_years_path
    assert_response :success
    assert_includes response.body, @year.name
  end

  test "commandant sees index" do
    sign_in @commandant
    get dormitory_academic_years_path
    assert_response :success
  end

  test "admin sees show" do
    sign_in @admin
    get dormitory_academic_year_path(@year)
    assert_response :success
    assert_includes response.body, @year.name
  end

  test "admin sees new form" do
    sign_in @admin
    get new_dormitory_academic_year_path
    assert_response :success
  end

  test "commandant cannot see new form" do
    sign_in @commandant
    get new_dormitory_academic_year_path
    assert_response :redirect
  end

  test "admin creates academic year" do
    sign_in @admin
    assert_difference -> { Dormitory::AcademicYear.count }, 1 do
      post dormitory_academic_years_path, params: {
        dormitory_academic_year: {
          name: "2027/2028", start_date: Date.new(2027, 9, 1), end_date: Date.new(2028, 8, 31)
        }
      }
    end
    assert_redirected_to dormitory_academic_year_path(Dormitory::AcademicYear.last)
  end

  test "admin cannot create with invalid dates" do
    sign_in @admin
    post dormitory_academic_years_path, params: {
      dormitory_academic_year: {
        name: "Invalid", start_date: Date.new(2027, 9, 1), end_date: Date.new(2026, 9, 1)
      }
    }
    assert_response :unprocessable_entity
  end

  test "admin activates pending year via update" do
    pending = dormitory_academic_years(:pending_year_2026_2027)
    Dormitory::AcademicYear.where(status: :active).update_all(status: :closed, closed_at: Time.current)
    sign_in @admin
    patch dormitory_academic_year_path(pending), params: {
      dormitory_academic_year: { status_event: "activate" }
    }
    assert_response :redirect
  end

  test "commandant cannot activate via update" do
    pending = dormitory_academic_years(:pending_year_2026_2027)
    sign_in @commandant
    patch dormitory_academic_year_path(pending), params: {
      dormitory_academic_year: { status_event: "activate" }
    }
    assert_response :redirect
  end

  test "admin closes active year via update" do
    Dormitory::AcademicYear.where(status: :active).update_all(status: :closed, closed_at: Time.current)
    year = Dormitory::AcademicYear.create!(
      name: "ToCloseTest", start_date: Date.current, end_date: Date.current + 1.year
    )
    year.do_activate!
    sign_in @admin
    patch dormitory_academic_year_path(year), params: {
      dormitory_academic_year: { status_event: "close" }
    }
    assert_redirected_to dormitory_academic_year_path(year)
    assert year.reload.closed?
  end

  test "admin edits academic year" do
    sign_in @admin
    patch dormitory_academic_year_path(@year), params: {
      dormitory_academic_year: { name: "Updated name" }
    }
    assert_redirected_to dormitory_academic_year_path(@year)
    assert_equal "Updated name", @year.reload.name
  end

  test "admin destroys pending year" do
    pending = dormitory_academic_years(:pending_year_2026_2027)
    sign_in @admin

    assert_difference -> { Dormitory::AcademicYear.kept.count }, -1 do
      delete dormitory_academic_year_path(pending)
    end
    assert_redirected_to dormitory_academic_years_path
    assert pending.reload.discarded?
  end

  test "admin cannot destroy active year" do
    sign_in @admin
    delete dormitory_academic_year_path(@year)
    assert_redirected_to dormitory_academic_years_path
    assert_not @year.reload.discarded?
  end

  test "commandant cannot destroy year" do
    pending = dormitory_academic_years(:pending_year_2026_2027)
    sign_in @commandant
    delete dormitory_academic_year_path(pending)
    assert_response :redirect
    assert_not pending.reload.discarded?
  end
end
