require "test_helper"

class Reporting::ReportCommentsControllerTest < ActionDispatch::IntegrationTest
  test "user can create comment" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:new_report)

    assert_difference "Reporting::ReportComment.count", 1 do
      assert_difference "OutboxEvent.count", 1 do
        post reporting_report_comments_path(report), params: {
          reporting_report_comment: { body: "Test comment" }
        }
      end
    end

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.comments.created"), flash[:notice]

    event = OutboxEvent.last
    assert_equal "reporting.report_comment.created", event.action
    assert_instance_of Reporting::ReportComment, event.record
  end

  test "author can destroy comment" do
    sign_in_as(users(:manager_user))
    report = reporting_reports(:new_report)
    comment = report.comments.create!(user: users(:manager_user), body: "Deletable")

    assert_difference "Reporting::ReportComment.count", -1 do
      assert_difference "OutboxEvent.count", 1 do
        delete reporting_report_comment_path(report, comment)
      end
    end

    assert_redirected_to reporting_report_path(report)
    assert_equal I18n.t("reporting.comments.destroyed"), flash[:notice]

    event = OutboxEvent.last
    assert_equal "reporting.report_comment.destroyed", event.action
  end

  test "non-author cannot destroy comment" do
    sign_in_as(users(:reporter_user))
    report = reporting_reports(:new_report)
    comment = report.comments.create!(user: users(:manager_user), body: "Not mine")

    delete reporting_report_comment_path(report, comment)
    assert_redirected_to root_path
    assert_equal I18n.t("pundit.not_authorized"), flash[:alert]
  end
end
