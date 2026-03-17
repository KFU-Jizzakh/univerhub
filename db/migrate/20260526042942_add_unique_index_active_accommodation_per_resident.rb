class AddUniqueIndexActiveAccommodationPerResident < ActiveRecord::Migration[8.1]
  def change
    add_index :dormitory_accommodations, :resident_id,
              unique: true,
              where: "status = 'active' AND discarded_at IS NULL",
              name: "idx_active_accommodation"
  end
end
