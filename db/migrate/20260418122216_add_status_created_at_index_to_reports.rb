class AddStatusCreatedAtIndexToReports < ActiveRecord::Migration[8.1]
  def change
    add_index :reports, [ :status, :created_at ], order: { created_at: :desc }
    remove_index :reports, :status
  end
end
