class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.datetime :deadline
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.integer :total_grade
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :reporter, null: true, foreign_key: { to_table: :users }
      t.references :reviewer, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :reports, :status
  end
end
