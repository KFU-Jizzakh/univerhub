require "test_helper"

class Reporting::ReportTemplateItemTest < ActiveSupport::TestCase
  test "valid with name and position" do
    template = reporting_report_templates(:draft_template)
    item = Reporting::ReportTemplateItem.new(name: "Test item", position: 1, report_template: template)
    assert item.valid?
  end

  test "invalid without name" do
    template = reporting_report_templates(:draft_template)
    item = Reporting::ReportTemplateItem.new(position: 1, report_template: template)
    assert_not item.valid?
    assert_includes item.errors[:name], "не может быть пустым"
  end

  test "invalid with negative position" do
    template = reporting_report_templates(:draft_template)
    item = Reporting::ReportTemplateItem.new(name: "Test", position: -1, report_template: template)
    assert_not item.valid?
    assert_includes item.errors[:position], "должно быть больше или равно 0"
  end

  test "ordered scope sorts by position" do
    template = reporting_report_templates(:draft_template)
    item2 = template.items.create!(name: "Second", position: 2)
    item1 = template.items.create!(name: "First", position: 1)

    ordered = template.items.ordered.to_a
    assert_equal [ item1, item2 ], ordered
  end
end
