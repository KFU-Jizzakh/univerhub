require "open3"
require "digest"
require "tmpdir"

module Reporting
  class PdfGenerator
    # PURPOSE: Generates PDF documents from Typst templates with ERB rendering, status watermarks, and cache-based invalidation
    # SPECIFICATION: SPEC-REPT-03
    def initialize(report, force: false)
      @report = report
      @force = force
    end

    def call
      if !@force && cached_pdf_valid?
        return @report.pdf_file
      end

      generate_pdf
    end

    private

    def cached_pdf_valid?
      @report.pdf_file.attached? &&
        @report.pdf_file.blob.metadata["cache_key"] == @report.pdf_cache_key
    end

    def generate_pdf
      template_path = resolve_template
      typ_content = ERB.new(File.read(template_path), trim_mode: "-").result(binding)

      Dir.mktmpdir do |dir|
        input_file = File.join(dir, "input.typ")
        output_file = File.join(dir, "output.pdf")

        File.write(input_file, typ_content)
        compile_typst(input_file, output_file)

        @report.pdf_file.purge if @report.pdf_file.attached?
        @report.pdf_file.attach(
          io: StringIO.new(File.binread(output_file)),
          filename: pdf_filename,
          content_type: "application/pdf"
        )
        @report.reload
        @report.pdf_file.blob.update!(metadata: { cache_key: @report.pdf_cache_key })
      end

      @report.pdf_file
    rescue StandardError => e
      Rails.logger.error("PDF generation failed for report #{@report.id}: #{e.message}")
      raise
    end

    def resolve_template
      path = @report.report_template&.pdf_template_path
      path || Reporting::ReportTemplate::PDF_TEMPLATES_DIR.join("generic.typ.erb")
    end

    def compile_typst(input_path, output_path)
      bin = Rails.configuration.typst_bin_path
      _stdout, stderr, status = Open3.capture3(bin, "compile", input_path, output_path)
      unless status.success?
        Rails.logger.error("typst compile stderr: #{stderr}")
        raise "typst compile failed for report #{@report.id}: #{stderr}"
      end
    end

    def pdf_filename
      name = @report.name.parameterize.presence || @report.id.to_s
      "#{name}.pdf"
    end

    def typst_escape(text)
      return "" if text.blank?
      text.to_s
        .gsub("\\") { "\\\\" }
        .gsub("#", "\\#")
        .gsub("[", "\\[")
        .gsub("]", "\\]")
        .gsub("{", "\\{")
        .gsub("}", "\\}")
        .gsub("@", "\\@")
        .gsub("$", "\\$")
        .gsub("`", "\\`")
        .gsub("_", "\\_")
        .gsub("*", "\\*")
        .gsub("~", "\\~")
        .gsub("<", "\\<")
        .gsub(">", "\\>")
        .gsub("\n", " \\\n")
    end

    def watermark_text
      case @report.status
      when "draft"        then "ЧЕРНОВИК"
      when "in_progress"  then "В РАБОТЕ"
      when "in_review"    then "НА ПРОВЕРКЕ"
      when "rejected"     then "ОТКЛОНЁН"
      when "new"          then "НОВЫЙ"
      when "reopened"     then "ПЕРЕОТКРЫТ"
      else nil
      end
    end

    def render_watermark
      text = watermark_text
      return "" unless text

      <<~TYPST
        #place(top + center, dy: 40%)[
          #rotate(-30deg)[
            #text(size: 60pt, fill: rgb(210, 210, 210), weight: "bold", tracking: 0.1em)[#{typst_escape(text)}]
          ]
        ]
      TYPST
    end

    def format_date(datetime)
      return "\u2014" unless datetime
      datetime.strftime("%d.%m.%Y")
    end

    def format_datetime(datetime)
      return "\u2014" unless datetime
      datetime.strftime("%d.%m.%Y %H:%M")
    end

    def user_name(user)
      return "\u2014" unless user&.profile
      user.profile.full_name
    end
  end
end
