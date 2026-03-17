require "test_helper"

module Reporting
  class ReportCommentTest < ActiveSupport::TestCase
    setup do
      @manager = users(:manager_user)
      Current.session = @manager.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    end

    teardown { Current.reset }

    test "valid with body" do
      report = reporting_reports(:new_report)
      comment = Reporting::ReportComment.new(report: report, user: users(:manager_user), body: "Test comment")
      assert comment.valid?
    end

    test "invalid without body" do
      report = reporting_reports(:new_report)
      comment = Reporting::ReportComment.new(report: report, user: users(:manager_user))
      assert_not comment.valid?
      assert_includes comment.errors[:body], "не может быть пустым"
    end

    test "invalid with overly long body" do
      report = reporting_reports(:new_report)
      comment = Reporting::ReportComment.new(report: report, user: users(:manager_user), body: "x" * 5001)
      assert_not comment.valid?
      assert_includes comment.errors[:body], "слишком длинный (максимум 5000 символов)"
    end

    test "recent scope orders by created_at desc" do
      report = reporting_reports(:new_report)
      older = report.comments.create!(user: users(:manager_user), body: "Older", created_at: 2.days.ago)
      newer = report.comments.create!(user: users(:manager_user), body: "Newer", created_at: 1.day.ago)

      assert_equal [ newer, older ], report.comments.recent.to_a
    end

    test "do_create! creates comment and OutboxEvent" do
      report = reporting_reports(:new_report)
      comment = report.comments.build(user: @manager, body: "New comment")

      assert_difference "Reporting::ReportComment.count", 1 do
        assert_difference "OutboxEvent.count", 1 do
          comment.do_create!
        end
      end

      assert_equal "reporting.report_comment.created", OutboxEvent.last.action
      assert_equal comment, OutboxEvent.last.record
    end

    test "do_update! updates comment and creates OutboxEvent" do
      report = reporting_reports(:new_report)
      comment = report.comments.create!(user: @manager, body: "Original")

      assert_difference "OutboxEvent.count", 1 do
        comment.do_update!(body: "Updated body")
      end

      assert_equal "Updated body", comment.reload.body
      assert_equal "reporting.report_comment.updated", OutboxEvent.last.action
    end

    test "do_destroy! destroys comment and creates OutboxEvent" do
      report = reporting_reports(:new_report)
      comment = report.comments.create!(user: @manager, body: "To delete")

      assert_difference "Reporting::ReportComment.count", -1 do
        assert_difference "OutboxEvent.count", 1 do
          comment.do_destroy!
        end
      end

      assert_equal "reporting.report_comment.destroyed", OutboxEvent.last.action
    end
  end
end
