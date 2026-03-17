class AddDiscardToReportingReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reporting_reports, :discarded_at, :datetime
    add_index :reporting_reports, :discarded_at
  end
end
