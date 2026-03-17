class CreateDormitoryBuildings < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_buildings do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.integer :floors_count, null: false, default: 1
      t.text :description
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dormitory_buildings, :name, unique: true
    add_index :dormitory_buildings, :discarded_at
  end
end
