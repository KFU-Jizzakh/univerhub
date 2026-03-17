require "test_helper"

class Reporting::ReportersControllerTest < ActionDispatch::IntegrationTest
  test "index shows reporters list" do
    sign_in_as(users(:visitor_user))
    get reporting_reporters_path
    assert_response :success
    assert_select "td", text: users(:reporter_user).email_address
  end

  test "show displays reporter reports" do
    sign_in_as(users(:visitor_user))
    get reporting_reporter_path(users(:reporter_user))
    assert_response :success
    assert_select "h2", /Reporter/
  end

  test "show redirects for non-reporter" do
    sign_in_as(users(:visitor_user))
    get reporting_reporter_path(users(:manager_user))
    assert_redirected_to reporting_reporters_path
    assert_equal I18n.t("reporting.reporters.not_a_reporter"), flash[:alert]
  end
end
