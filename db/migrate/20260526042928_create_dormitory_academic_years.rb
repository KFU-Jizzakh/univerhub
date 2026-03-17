class CreateDormitoryAcademicYears < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_academic_years do |t|
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :closed_at
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :dormitory_academic_years, :name, unique: true, where: "discarded_at IS NULL"
    add_index :dormitory_academic_years, :status,
              unique: true,
              where: "status = 'active'",
              name: "idx_academic_years_active"
    add_index :dormitory_academic_years, :discarded_at
  end
end
