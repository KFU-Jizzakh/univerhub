class CreateDormitoryBatchOperationErrors < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_batch_operation_errors do |t|
      t.references :batch_operation, null: false, foreign_key: { to_table: :dormitory_batch_operations }
      t.references :resident, foreign_key: { to_table: :dormitory_residents }
      t.references :accommodation, foreign_key: { to_table: :dormitory_accommodations }
      t.text :error_message
      t.timestamps
    end
  end
end
