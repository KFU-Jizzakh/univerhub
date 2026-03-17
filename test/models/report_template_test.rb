require "test_helper"

class Reporting::ReportTemplateTest < ActiveSupport::TestCase
  setup do
    @manager = users(:manager_user)
    Current.session = @manager.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
  end

  teardown { Current.reset }

  test "requires name" do
    template = Reporting::ReportTemplate.new(creator: @manager)
    assert_not template.valid?
    assert template.errors[:name].any?
  end

  test "available scope returns only published templates" do
    assert_includes Reporting::ReportTemplate.available, reporting_report_templates(:published_template)
    assert_not_includes Reporting::ReportTemplate.available, reporting_report_templates(:draft_template)
  end

  test "do_publish! transitions draft to published" do
    reporting_report_templates(:draft_template).do_publish!
    assert reporting_report_templates(:draft_template).reload.published?
  end

  test "do_publish! creates OutboxEvent" do
    assert_difference "OutboxEvent.count", 1 do
      reporting_report_templates(:draft_template).do_publish!
    end
  end

  test "do_archive! transitions published to archived" do
    reporting_report_templates(:published_template).do_archive!
    assert reporting_report_templates(:published_template).reload.archived?
  end

  test "do_archive! creates OutboxEvent" do
    assert_difference "OutboxEvent.count", 1 do
      reporting_report_templates(:published_template).do_archive!
    end
  end
end
