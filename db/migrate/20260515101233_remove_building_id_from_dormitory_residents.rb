class RemoveBuildingIdFromDormitoryResidents < ActiveRecord::Migration[8.1]
  def change
    remove_index :dormitory_residents, name: "index_dormitory_residents_on_building_id"
    remove_index :dormitory_residents, name: "index_dormitory_residents_on_building_id_and_status"
    remove_foreign_key :dormitory_residents, column: :building_id
    remove_column :dormitory_residents, :building_id, :bigint
  end
end
