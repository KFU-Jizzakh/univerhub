class AddPdfSupportToReporting < ActiveRecord::Migration[8.1]
  def change
    add_column :reporting_reports, :report_template_id, :bigint
    add_foreign_key :reporting_reports, :reporting_report_templates, column: :report_template_id
    add_column :reporting_report_templates, :pdf_template, :string
  end
end
