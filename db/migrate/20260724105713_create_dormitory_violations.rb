class CreateDormitoryViolations < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_violations do |t|
      t.references :resident, null: false, foreign_key: { to_table: :dormitory_residents }
      t.integer :violation_type, null: false
      t.datetime :occurred_at, null: false
      t.string :place, null: false
      t.text :description, null: false
      t.integer :status, null: false, default: 0
      t.date :reviewed_at
      t.text :review_result
      t.text :commandant_comment
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dormitory_violations, :discarded_at
    add_index :dormitory_violations, :status
    add_index :dormitory_violations, :violation_type
  end
end
