class CreateDormitoryAccommodations < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_accommodations, if_not_exists: true do |t|
      t.references :resident, null: false, foreign_key: { to_table: :dormitory_residents, if_not_exists: true }
      t.references :room, null: false, foreign_key: { to_table: :dormitory_rooms, if_not_exists: true }
      t.string :application_number, null: false
      t.string :contract_number, null: false
      t.date :start_date, null: false
      t.date :actual_end_date
      t.string :status, default: "active", null: false
      t.string :eviction_reason
      t.text :comment
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dormitory_accommodations, :status, if_not_exists: true
    add_index :dormitory_accommodations, :discarded_at, if_not_exists: true
    add_index :dormitory_accommodations, :resident_id, if_not_exists: true
    add_index :dormitory_accommodations, :room_id, if_not_exists: true

    add_foreign_key :dormitory_accommodations, :dormitory_residents,
                    column: :resident_id, if_not_exists: true
  end
end
