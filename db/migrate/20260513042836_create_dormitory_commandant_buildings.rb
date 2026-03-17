class CreateDormitoryCommandantBuildings < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_commandant_buildings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: { to_table: :dormitory_buildings }
      t.datetime :deactivated_at

      t.timestamps
    end

    add_index :dormitory_commandant_buildings,
              [ :user_id, :building_id ],
              unique: true,
              where: "deactivated_at IS NULL",
              name: "index_active_commandant_buildings"
  end
end
