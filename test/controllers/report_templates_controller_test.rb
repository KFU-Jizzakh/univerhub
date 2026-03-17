require "test_helper"

class Reporting::ReportTemplatesControllerTest < ActionDispatch::IntegrationTest
  # ── index ─────────────────────────────────────────────────────

  test "manager sees all templates" do
    sign_in_as(users(:manager_user))
    get reporting_report_templates_path
    assert_response :success
    assert_select "td", text: /Draft Template/
    assert_select "td", text: /Published Template/
  end

  test "visitor sees only published templates" do
    sign_in_as(users(:visitor_user))
    get reporting_report_templates_path
    assert_response :success
    assert_select "td", text: /Published Template/
    assert_select "td", { text: /Draft Template/, count: 0 }
  end

  # ── show ──────────────────────────────────────────────────────

  test "manager can view draft template" do
    sign_in_as(users(:manager_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_response :success
  end

  test "visitor can view published template" do
    sign_in_as(users(:visitor_user))
    get reporting_report_template_path(reporting_report_templates(:published_template))
    assert_response :success
  end

  test "visitor cannot view draft template" do
    sign_in_as(users(:visitor_user))
    get reporting_report_template_path(reporting_report_templates(:draft_template))
    assert_redirected_to root_path
  end

  # ── new/create ────────────────────────────────────────────────

  test "manager can create template" do
    sign_in_as(users(:manager_user))

    assert_difference("Reporting::ReportTemplate.count", 1) do
      post reporting_report_templates_path, params: {
        reporting_report_template: { name: "New Template", description: "Test" }
      }
    end

    assert_redirected_to reporting_report_template_path(Reporting::ReportTemplate.last)
    assert_equal I18n.t("reporting.report_templates.created"), flash[:notice]
  end

  test "non-manager cannot create template" do
    sign_in_as(users(:reporter_user))

    post reporting_report_templates_path, params: {
      reporting_report_template: { name: "Bad Template" }
    }

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── edit/update ───────────────────────────────────────────────

  test "creator can edit draft template" do
    sign_in_as(users(:manager_user))
    template = reporting_report_templates(:draft_template)

    get edit_reporting_report_template_path(template)
    assert_response :success
  end

  test "creator can update draft template" do
    sign_in_as(users(:manager_user))
    template = reporting_report_templates(:draft_template)

    patch reporting_report_template_path(template), params: {
      reporting_report_template: { name: "Updated Template" }
    }

    assert_redirected_to reporting_report_template_path(template)
    assert_equal I18n.t("reporting.report_templates.updated"), flash[:notice]
    template.reload
    assert_equal "Updated Template", template.name
  end

  test "non-creator cannot edit template" do
    sign_in_as(users(:reporter_user))
    template = reporting_report_templates(:draft_template)

    get edit_reporting_report_template_path(template)
    assert_redirected_to root_path
  end

  # ── destroy ───────────────────────────────────────────────────

  test "creator can destroy draft template" do
    sign_in_as(users(:manager_user))
    template = reporting_report_templates(:draft_template)

    assert_difference("Reporting::ReportTemplate.count", -1) do
      delete reporting_report_template_path(template)
    end

    assert_redirected_to reporting_report_templates_path
    assert_equal I18n.t("reporting.report_templates.destroyed"), flash[:notice]
  end

  test "non-creator cannot destroy template" do
    sign_in_as(users(:reporter_user))
    template = reporting_report_templates(:draft_template)

    delete reporting_report_template_path(template)
    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── publish ───────────────────────────────────────────────────

  test "creator can publish draft template" do
    sign_in_as(users(:manager_user))
    template = reporting_report_templates(:draft_template)

    patch publish_reporting_report_template_path(template)

    assert_redirected_to reporting_report_template_path(template)
    assert_equal I18n.t("reporting.report_templates.published"), flash[:notice]
    template.reload
    assert template.published?
  end

  test "non-creator cannot publish template" do
    sign_in_as(users(:reporter_user))
    template = reporting_report_templates(:draft_template)

    patch publish_reporting_report_template_path(template)

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── archive ───────────────────────────────────────────────────

  test "creator can archive published template" do
    sign_in_as(users(:manager_user))
    template = reporting_report_templates(:published_template)

    patch archive_reporting_report_template_path(template)

    assert_redirected_to reporting_report_template_path(template)
    assert_equal I18n.t("reporting.report_templates.archived"), flash[:notice]
    template.reload
    assert template.archived?
  end

  test "non-creator cannot archive template" do
    sign_in_as(users(:reporter_user))
    template = reporting_report_templates(:published_template)

    patch archive_reporting_report_template_path(template)

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end
end
