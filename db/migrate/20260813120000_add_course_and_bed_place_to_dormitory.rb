class AddCourseAndBedPlaceToDormitory < ActiveRecord::Migration[8.1]
  # PURPOSE: Add resident course, room allowed_courses, and accommodation bed_label + course snapshot for the automatic place issuance flow
  # SPECIFICATION: SPEC-DORM-12

  def up
    add_column :dormitory_residents, :course, :integer, null: false, default: 1
    add_column :dormitory_rooms, :allowed_courses, :integer, array: true
    add_column :dormitory_accommodations, :bed_label, :string
    add_column :dormitory_accommodations, :course, :integer, null: false, default: 1

    backfill_accommodation_courses
    backfill_bed_labels
  end

  def down
    remove_column :dormitory_accommodations, :course
    remove_column :dormitory_accommodations, :bed_label
    remove_column :dormitory_rooms, :allowed_courses
    remove_column :dormitory_residents, :course
  end

  private

  def backfill_accommodation_courses
    execute <<~SQL.squish
      UPDATE dormitory_accommodations
      SET course = dormitory_residents.course
      FROM dormitory_residents
      WHERE dormitory_accommodations.resident_id = dormitory_residents.id
    SQL
  end

  def backfill_bed_labels
    rows = execute(<<~SQL.squish).to_a
      SELECT a.id, a.room_id, r.capacity
      FROM dormitory_accommodations a
      JOIN dormitory_rooms r ON r.id = a.room_id
      WHERE a.discarded_at IS NULL AND a.status IN ('active', 'pending')
      ORDER BY a.room_id, a.created_at ASC, a.id ASC
    SQL

    counts = Hash.new(0)
    rows.each do |row|
      index = counts[row["room_id"]]
      next if index >= row["capacity"].to_i

      counts[row["room_id"]] = index + 1
      label = label_for(index)
      execute <<~SQL.squish
        UPDATE dormitory_accommodations
        SET bed_label = '#{label}'
        WHERE id = '#{row["id"]}'
      SQL
    end
  end

  def label_for(index)
    label = +""
    n = index + 1
    while n.positive?
      n -= 1
      label.prepend((65 + n % 26).chr)
      n /= 26
    end
    label
  end
end
