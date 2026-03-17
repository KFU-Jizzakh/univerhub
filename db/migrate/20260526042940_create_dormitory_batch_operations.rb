class CreateDormitoryBatchOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_batch_operations do |t|
      t.references :academic_year, null: false, foreign_key: { to_table: :dormitory_academic_years }
      t.references :building, null: false, foreign_key: { to_table: :dormitory_buildings }
      t.string :operation_type, null: false
      t.string :eviction_reason
      t.text :comment
      t.integer :total_count, default: 0
      t.integer :success_count, default: 0
      t.integer :error_count, default: 0
      t.string :status, null: false, default: "pending"
      t.references :performed_by, foreign_key: { to_table: :users }
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :dormitory_batch_operations, :status
  end
end
