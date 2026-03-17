require "test_helper"

class OutboxEventTest < ActiveSupport::TestCase
  test "track_event stores the explicit payload, not the full record attributes" do
    report = reporting_reports(:draft_report)
    report.update!(
      reporter: users(:reporter_user),
      reviewer: users(:reviewer_user),
      deadline: 1.month.from_now
    )
    report.report_items.create!(name: "Пункт")
    Current.session = users(:manager_user).sessions.create!

    assert_difference -> { OutboxEvent.count }, 1 do
      report.do_publish!
    end

    event = OutboxEvent.where(record: report, action: "reporting.report.published").last
    assert_equal %w[reporter_id reviewer_id deadline].sort, event.payload.keys.sort
    assert_not event.payload.key?("id")
    assert_not event.payload.key?("created_at")
    assert_not event.payload.key?("name")
  end

  test "track_event without explicit payload stores empty hash" do
    Current.session = users(:reporter_user).sessions.create!
    report = reporting_reports(:new_report)

    report.do_take_in_progress!
    event = OutboxEvent.where(record: report, action: "reporting.report.taken_in_progress").last
    assert_equal({}, event.payload)
  end
end
