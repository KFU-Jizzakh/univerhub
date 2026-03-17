require "test_helper"

class Reporting::ReportsControllerTest < ActionDispatch::IntegrationTest
  # ── index ─────────────────────────────────────────────────────

  test "manager sees only their own reports" do
    sign_in_as(users(:manager_user))
    get reporting_reports_path
    assert_response :success
    assert_select "td", text: /Draft Report/
    assert_select "td", text: /New Report/
  end

  test "reporter sees only assigned reports" do
    sign_in_as(users(:reporter_user))
    get reporting_reports_path
    assert_response :success
    assert_select "td", text: /New Report/
    assert_select "td", text: /In Progress Report/
    assert_select "td", { text: /Draft Report/, count: 0 }
  end

  test "reviewer sees only assigned reports" do
    sign_in_as(users(:reviewer_user))
    get reporting_reports_path
    assert_response :success
    assert_select "td", text: /New Report/
    assert_select "td", text: /In Review Report/
    assert_select "td", { text: /Draft Report/, count: 0 }
  end

  test "visitor sees only non-draft reports" do
    sign_in_as(users(:visitor_user))
    get reporting_reports_path
    assert_response :success
    assert_select "td", text: /New Report/
    assert_select "td", { text: /Draft Report/, count: 0 }
  end

  # ── show ──────────────────────────────────────────────────────

  test "creator can view their report" do
    sign_in_as(users(:manager_user))
    get reporting_report_path(reporting_reports(:draft_report))
    assert_response :success
    assert_select "h2", /Draft Report/
  end

  test "reporter can view assigned report" do
    sign_in_as(users(:reporter_user))
    get reporting_report_path(reporting_reports(:new_report))
    assert_response :success
  end

  test "reviewer can view assigned report" do
    sign_in_as(users(:reviewer_user))
    get reporting_report_path(reporting_reports(:in_review_report))
    assert_response :success
  end

  test "visitor can view published report" do
    sign_in_as(users(:visitor_user))
    get reporting_report_path(reporting_reports(:new_report))
    assert_response :success
  end

  test "visitor cannot view draft report" do
    sign_in_as(users(:visitor_user))
    get reporting_report_path(reporting_reports(:draft_report))
    assert_redirected_to root_path
  end

  # ── new/create ────────────────────────────────────────────────

  test "manager can create report" do
    sign_in_as(users(:manager_user))

    assert_difference("Reporting::Report.count", 1) do
      post reporting_reports_path, params: {
        reporting_report: {
          name: "New Test Report",
          description: "Test description",
          deadline: 1.week.from_now.to_date,
          reporter_id: users(:reporter_user).id,
          reviewer_id: users(:reviewer_user).id
        }
      }
    end

    assert_redirected_to reporting_report_path(Reporting::Report.last)
    assert_equal I18n.t("reporting.reports.created"), flash[:notice]
  end

  test "manager can create report from template" do
    sign_in_as(users(:manager_user))
    template = reporting_report_templates(:published_template)
    template.items.create!(name: "Template Item", position: 0)

    assert_difference("Reporting::Report.count", 1) do
      assert_difference("Reporting::ReportItem.count", 1) do
        post reporting_reports_path, params: {
          reporting_report: {
            name: "Templated Report",
            deadline: 1.week.from_now.to_date,
            reporter_id: users(:reporter_user).id,
            reviewer_id: users(:reviewer_user).id,
            report_template_id: template.id
          }
        }
      end
    end

    report = Reporting::Report.last
    assert_redirected_to reporting_report_path(report)
    assert_equal template.id, report.report_template_id
    assert_equal 1, report.report_items.count
    assert_equal "Template Item", report.report_items.first.name
  end

  test "create with unavailable template shows error" do
    sign_in_as(users(:manager_user))

      post reporting_reports_path, params: {
        reporting_report: {
          name: "Bad Report",
          deadline: 1.week.from_now.to_date,
          reporter_id: users(:reporter_user).id,
          reviewer_id: users(:reviewer_user).id,
          report_template_id: 999_999
        }
      }

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "non-manager cannot create report" do
    sign_in_as(users(:reporter_user))

    post reporting_reports_path, params: {
      reporting_report: {
        name: "Unauthorized Report",
        deadline: 1.week.from_now.to_date,
        reporter_id: users(:reporter_user).id,
        reviewer_id: users(:reviewer_user).id
      }
    }

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── edit/update ───────────────────────────────────────────────

  test "creator can edit draft report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:draft_report)

    get edit_reporting_report_path(report)
    assert_response :success
    assert_select "form"
  end

  test "creator can update draft report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:draft_report)

    patch reporting_report_path(report), params: {
      reporting_report: { name: "Updated Draft", deadline: 2.weeks.from_now.to_date }
    }

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.updated"), flash[:notice]
    report.reload
    assert_equal "Updated Draft", report.name
  end

  test "non-creator cannot edit report" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:draft_report)

    get edit_reporting_report_path(report)
    assert_redirected_to root_path
  end

  # ── destroy ───────────────────────────────────────────────────

  test "creator can destroy draft report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:draft_report)

    assert_difference("Reporting::Report.kept.count", -1) do
      delete reporting_report_path(report)
    end

    assert report.reload.discarded?
    assert_redirected_to reporting_reports_path
    assert_equal I18n.t("reporting.reports.destroyed"), flash[:notice]
  end

  test "non-creator cannot destroy report" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:draft_report)

    delete reporting_report_path(report)
    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── publish ───────────────────────────────────────────────────

  test "creator can publish draft with items" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:draft_report)
    report.report_items.create!(name: "Item for publish")
    report.update!(reporter: users(:reporter_user), reviewer: users(:reviewer_user), deadline: 1.week.from_now)

    patch publish_reporting_report_path(report)

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.published"), flash[:notice]
    report.reload
    assert report.new?
  end

  test "publish draft without items fails" do
    sign_in_as(users(:manager_user))
    report = Reporting::Report.create!(name: "Empty Draft", status: "draft", creator: users(:manager_user))
    report.update!(reporter: users(:reporter_user), reviewer: users(:reviewer_user), deadline: 1.week.from_now)

    patch publish_reporting_report_path(report)

    assert_redirected_to reporting_report_path(report)
    report.reload
    assert report.draft?
  end

  # ── take_in_progress ──────────────────────────────────────────

  test "reporter can take new report in progress" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:new_report)

    patch take_in_progress_reporting_report_path(report)

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.taken_in_progress"), flash[:notice]
    report.reload
    assert report.in_progress?
  end

  test "non-reporter cannot take report in progress" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:new_report)

    patch take_in_progress_reporting_report_path(report)

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── submit ────────────────────────────────────────────────────

  test "reporter can submit in_progress report" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:in_progress_report)

    patch submit_reporting_report_path(report)

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.submitted"), flash[:notice]
    report.reload
    assert report.in_review?
    assert_not_nil report.submitted_at
  end

  test "non-reporter cannot submit report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_progress_report)

    patch submit_reporting_report_path(report)

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── accept ────────────────────────────────────────────────────

  test "reviewer can accept in_review report with all grades" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:in_review_report)
    report.report_items.create!(name: "Graded item", grade: 8, max_grade: 10)

    patch accept_reporting_report_path(report)

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.accepted"), flash[:notice]
    report.reload
    assert report.accepted?
  end

  test "non-reviewer cannot accept report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_review_report)

    patch accept_reporting_report_path(report)

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── reject ────────────────────────────────────────────────────

  test "reject with valid reason transitions to rejected" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:in_review_report)

    patch reject_reporting_report_path(report), params: { rejection_reason: "Недостаточно данных" }

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.rejected"), flash[:notice]
    report.reload
    assert report.rejected?
    assert_equal "Недостаточно данных", report.rejection_reason
  end

  test "reject without reason fails validation" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:in_review_report)

    patch reject_reporting_report_path(report), params: { rejection_reason: "" }

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.errors.cannot_reject"), flash[:alert]
    report.reload
    assert report.in_review?
  end

  test "reject from non-reviewable state is unauthorized" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:new_report)

    patch reject_reporting_report_path(report), params: { rejection_reason: "Попытка отклонить" }

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  test "reject with overly long reason fails" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:in_review_report)

    patch reject_reporting_report_path(report), params: { rejection_reason: "x" * 2001 }

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.errors.cannot_reject"), flash[:alert]
    report.reload
    assert report.in_review?
  end

  # ── reopen ────────────────────────────────────────────────────

  test "reporter can reopen rejected report" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:rejected_report)

    patch reopen_reporting_report_path(report)

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.reopened"), flash[:notice]
    report.reload
    assert report.reopened?
  end

  test "non-reporter cannot reopen report" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:rejected_report)

    patch reopen_reporting_report_path(report)

    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end

  # ── pdf ──────────────────────────────────────────────────────

  test "authorized user can download pdf" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_review_report)

    get pdf_reporting_report_path(report)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "visitor cannot download pdf for draft" do
    sign_in_as(users(:visitor_user))
    report = reporting_reports(:draft_report)

    get pdf_reporting_report_path(report)
    assert_redirected_to root_path
  end

  # ── regenerate_pdf ────────────────────────────────────────────

  test "manager can regenerate pdf" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_review_report)

    post regenerate_pdf_reporting_report_path(report)
    assert_redirected_to pdf_reporting_report_path(report)
    assert_equal I18n.t("reporting.reports.pdf_regenerated"), flash[:notice]
  end

  test "reporter cannot regenerate pdf" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:in_review_report)

    post regenerate_pdf_reporting_report_path(report)
    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end
end
