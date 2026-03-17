require "test_helper"

class Reporting::PdfGeneratorTest < ActiveSupport::TestCase
  setup do
    @manager  = users(:manager_user)
    @reporter = users(:reporter_user)
    @reviewer = users(:reviewer_user)
    Current.session = @manager.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")

    [ @manager, @reporter, @reviewer ].each do |u|
      u.create_profile!(first_name: "Test", last_name: "User") unless u.profile
    end

    @report = Reporting::Report.create!(
      name: "Test Report PDF",
      creator: @manager,
      reporter: @reporter,
      reviewer: @reviewer,
      deadline: 1.week.from_now,
      status: "in_review"
    )
    @report.report_items.create!(name: "Item 1", content: "Content 1", grade: 4, max_grade: 5)
  end

  teardown { Current.reset }

  test "call generates pdf and attaches to report" do
    assert_not @report.pdf_file.attached?

    Reporting::PdfGenerator.new(@report).call

    @report.reload
    assert @report.pdf_file.attached?
    assert_equal "application/pdf", @report.pdf_file.content_type
    assert @report.pdf_file.byte_size > 0
  end

  test "call returns cached pdf on second call" do
    first = Reporting::PdfGenerator.new(@report).call
    @report.reload
    first_blob_id = @report.pdf_file.blob.id

    Reporting::PdfGenerator.new(@report).call
    @report.reload
    assert_equal first_blob_id, @report.pdf_file.blob.id
  end

  test "call regenerates when force is true" do
    Reporting::PdfGenerator.new(@report).call
    @report.reload
    first_blob_id = @report.pdf_file.blob.id

    Reporting::PdfGenerator.new(@report, force: true).call
    @report.reload
    assert_not_equal first_blob_id, @report.pdf_file.blob.id
  end

  test "call regenerates when report data changes" do
    Reporting::PdfGenerator.new(@report).call
    @report.reload
    first_blob_id = @report.pdf_file.blob.id

    @report.update!(total_grade: 42)
    Reporting::PdfGenerator.new(@report).call
    @report.reload
    assert_not_equal first_blob_id, @report.pdf_file.blob.id
  end

  test "call uses generic template when no report_template" do
    assert_nil @report.report_template

    Reporting::PdfGenerator.new(@report).call

    @report.reload
    assert @report.pdf_file.attached?
  end

  test "call uses specific template when report_template has pdf_template" do
    template = reporting_report_templates(:published_template)
    template.update!(pdf_template: "generic")
    @report.update!(report_template: template)

    Reporting::PdfGenerator.new(@report).call

    @report.reload
    assert @report.pdf_file.attached?
  end

  test "call falls back to generic when pdf_template file missing" do
    template = reporting_report_templates(:published_template)
    template.update!(pdf_template: "nonexistent")
    @report.update!(report_template: template)

    Reporting::PdfGenerator.new(@report).call

    @report.reload
    assert @report.pdf_file.attached?
  end

  test "typst_escape escapes special characters" do
    generator = Reporting::PdfGenerator.new(@report)
    input = "text # $ @ [ ] { } \\ _ * ~ < > end"
    escaped = generator.send(:typst_escape, input)

    assert_includes escaped, "\\#"
    assert_includes escaped, "\\$"
    assert_includes escaped, "\\@"
    assert_includes escaped, "\\["
    assert_includes escaped, "\\]"
    assert_includes escaped, "\\{"
    assert_includes escaped, "\\}"
    assert_includes escaped, "\\_"
    assert_includes escaped, "\\*"
    assert_includes escaped, "\\~"
    assert_includes escaped, "\\<"
    assert_includes escaped, "\\>"
    assert_equal 1, escaped.scan("\\\\").length
  end

  test "typst_escape converts newlines to typst line breaks" do
    generator = Reporting::PdfGenerator.new(@report)
    escaped = generator.send(:typst_escape, "line1\nline2")

    assert_includes escaped, " \\\n"
  end

  test "typst_escape returns empty for blank" do
    generator = Reporting::PdfGenerator.new(@report)
    assert_equal "", generator.send(:typst_escape, "")
    assert_equal "", generator.send(:typst_escape, nil)
  end

  test "watermark_text returns text for non-accepted statuses" do
    %w[draft in_progress in_review rejected new reopened].each do |status|
      @report.update_column(:status, status)
      generator = Reporting::PdfGenerator.new(@report)
      assert generator.send(:watermark_text).present?, "expected watermark for #{status}"
    end
  end

  test "watermark_text returns nil for accepted status" do
    @report.update_column(:status, "accepted")
    generator = Reporting::PdfGenerator.new(@report)
    assert_nil generator.send(:watermark_text)
  end

  test "pdf_cache_key changes when item grade changes" do
    key_before = @report.pdf_cache_key
    @report.report_items.first.update!(grade: 3)
    key_after = @report.pdf_cache_key
    assert_not_equal key_before, key_after
  end

  test "pdf_cache_key includes template digest" do
    template = reporting_report_templates(:published_template)
    template.update!(pdf_template: "generic")
    @report.update!(report_template: template)

    key = @report.pdf_cache_key
    assert key.present?
  end
end
