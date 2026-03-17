require "test_helper"

class Reporting::ReportItemsControllerTest < ActionDispatch::IntegrationTest
  test "reporter can edit item" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:in_progress_report)
    item = report.report_items.create!(name: "Editable item")

    get edit_reporting_report_report_item_path(report, item)
    assert_response :success
  end

  test "reporter can update item content" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:in_progress_report)
    item = report.report_items.create!(name: "Editable item")

    patch reporting_report_report_item_path(report, item), params: {
      reporting_report_item: { content: "Updated content" }
    }

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.report_items.updated"), flash[:notice]
    item.reload
    assert_equal "Updated content", item.content
  end

  test "non-reporter cannot edit item" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_progress_report)
    item = report.report_items.create!(name: "Item")

    get edit_reporting_report_report_item_path(report, item)
    assert_redirected_to root_path
  end

  test "reviewer can grade item" do
    sign_in_as(users(:reviewer_user))
    report = reporting_reports(:in_review_report)
    item = report.report_items.create!(name: "Gradable item", max_grade: 10)

    patch grade_reporting_report_report_item_path(report, item), params: {
      reporting_report_item: { grade: 8, grade_comment: "Good work" }
    }

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.report_items.graded"), flash[:notice]
    item.reload
    assert_equal 8, item.grade
  end

  test "non-reviewer cannot grade item" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:in_review_report)
    item = report.report_items.create!(name: "Item", max_grade: 10)

    patch grade_reporting_report_report_item_path(report, item), params: {
      reporting_report_item: { grade: 8 }
    }

    assert_redirected_to root_path
  end
end
