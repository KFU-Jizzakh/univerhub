class AddUniqueIndexRoomBedLabelOnDormitoryAccommodations < ActiveRecord::Migration[8.1]
  def change
    add_index :dormitory_accommodations, [ :room_id, :bed_label ],
              unique: true,
              where: "bed_label IS NOT NULL AND discarded_at IS NULL AND status IN ('active', 'pending')",
              name: "idx_room_bed_label"
  end
end
