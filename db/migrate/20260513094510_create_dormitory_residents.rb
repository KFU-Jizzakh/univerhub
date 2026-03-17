class CreateDormitoryResidents < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_residents do |t|
      t.string :last_name, null: false
      t.string :first_name, null: false
      t.string :middle_name
      t.integer :gender, null: false, default: 0
      t.date :date_of_birth, null: false
      t.string :phone
      t.string :email
      t.string :student_ticket_number, null: false
      t.integer :status, null: false, default: 0
      t.references :building, null: false, foreign_key: { to_table: :dormitory_buildings }
      t.references :current_room, foreign_key: { to_table: :dormitory_rooms }
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dormitory_residents, :student_ticket_number, unique: true
    add_index :dormitory_residents, :discarded_at
    add_index :dormitory_residents, [ :building_id, :status ]
  end
end
