class RenameReportingTables < ActiveRecord::Migration[8.1]
  def change
    # Rename tables
    # PostgreSQL automatically updates FK constraints on rename_table
    rename_table :reports, :reporting_reports
    rename_table :report_templates, :reporting_report_templates
    rename_table :report_items, :reporting_report_items
    rename_table :report_template_items, :reporting_report_template_items
    rename_table :report_comments, :reporting_report_comments
  end
end
