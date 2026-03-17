class AddPlannedEndDateAndReferencesToDormitoryAccommodations < ActiveRecord::Migration[8.1]
  def up
    # Add columns as nullable first
    add_column :dormitory_accommodations, :planned_end_date, :date
    add_reference :dormitory_accommodations, :academic_year
    add_reference :dormitory_accommodations, :renewal_source

    # Backfill planned_end_date for existing records
    execute <<-SQL.squish
      UPDATE dormitory_accommodations
      SET planned_end_date = COALESCE(start_date, CURRENT_DATE) + INTERVAL '1 year'
      WHERE planned_end_date IS NULL
    SQL

    # Backfill academic_year_id from active year if one exists
    active_year_id = select_value("SELECT id FROM dormitory_academic_years WHERE status = 'active' LIMIT 1")
    if active_year_id
      execute "UPDATE dormitory_accommodations SET academic_year_id = #{active_year_id} WHERE academic_year_id IS NULL"
    else
      # If no active year exists but there are records, this will fail
      count = select_value("SELECT COUNT(*) FROM dormitory_accommodations WHERE academic_year_id IS NULL").to_i
      if count > 0
        raise "Cannot make academic_year_id NOT NULL: #{count} accommodations have no academic_year_id " \
              "and there is no active academic year to backfill. Create an active academic year first."
      end
    end

    # Change to NOT NULL
    change_column_null :dormitory_accommodations, :planned_end_date, false
    change_column_null :dormitory_accommodations, :academic_year_id, false

    # Foreign keys
    add_foreign_key :dormitory_accommodations, :dormitory_academic_years, column: :academic_year_id
    add_foreign_key :dormitory_accommodations, :dormitory_accommodations, column: :renewal_source_id

    # Indexes
    add_index :dormitory_accommodations, :planned_end_date, name: "idx_accommodations_planned_end_date"
  end

  def down
    remove_index :dormitory_accommodations, name: "idx_accommodations_planned_end_date"
    remove_foreign_key :dormitory_accommodations, :dormitory_accommodations, column: :renewal_source_id
    remove_foreign_key :dormitory_accommodations, :dormitory_academic_years, column: :academic_year_id
    remove_reference :dormitory_accommodations, :renewal_source
    remove_reference :dormitory_accommodations, :academic_year
    remove_column :dormitory_accommodations, :planned_end_date
  end
end
