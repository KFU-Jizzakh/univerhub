class CreateDormitoryRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_rooms do |t|
      t.string :number, null: false
      t.references :building, null: false, foreign_key: { to_table: :dormitory_buildings }
      t.integer :floor, null: false
      t.integer :capacity, null: false, default: 1
      t.integer :gender_restriction
      t.integer :current_occupancy, null: false, default: 0
      t.string :status, null: false, default: "free"
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dormitory_rooms, [ :building_id, :number ], unique: true, where: "discarded_at IS NULL"
    add_index :dormitory_rooms, :status
    add_index :dormitory_rooms, :discarded_at
  end
end
