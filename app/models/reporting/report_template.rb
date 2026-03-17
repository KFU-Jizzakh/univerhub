module Reporting
  class ReportTemplate < ApplicationRecord
    # PURPOSE: Report template defining ordered items structure, publish/archive lifecycle, and Typst PDF template selection
    # SPECIFICATION: SPEC-REPT-02
    include Trackable

    PDF_TEMPLATES_DIR = Rails.root.join("app/views/reporting/pdf_templates")

    belongs_to :creator, class_name: "User"
    has_many :items, class_name: "Reporting::ReportTemplateItem", dependent: :destroy, foreign_key: "report_template_id"

    enum :status, { draft: 0, published: 1, archived: 2 }

    validates :name, presence: true

    scope :available, -> { where(status: :published) }

    validates :pdf_template, format: { with: /\A[a-zA-Z0-9_]+\z/, message: :invalid_pdf_template }, allow_nil: true

    def pdf_template_path
      if pdf_template.present?
        path = PDF_TEMPLATES_DIR.join("#{pdf_template}.typ.erb").cleanpath
        return path if path.to_s.start_with?("#{PDF_TEMPLATES_DIR}/") && path.exist?
      end
      PDF_TEMPLATES_DIR.join("generic.typ.erb")
    end

    def do_publish!
      track_event("reporting.report_template.published", { name: name }) { published! }
    end

    def do_archive!
      track_event("reporting.report_template.archived", { name: name }) { archived! }
    end
  end
end
