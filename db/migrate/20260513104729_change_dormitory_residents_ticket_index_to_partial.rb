class ChangeDormitoryResidentsTicketIndexToPartial < ActiveRecord::Migration[8.1]
  def up
    remove_index :dormitory_residents, name: :index_dormitory_residents_on_student_ticket_number
    add_index :dormitory_residents, :student_ticket_number,
              unique: true,
              where: "discarded_at IS NULL",
              name: :index_dormitory_residents_on_ticket_unique_kept
  end

  def down
    remove_index :dormitory_residents, name: :index_dormitory_residents_on_ticket_unique_kept
    add_index :dormitory_residents, :student_ticket_number, unique: true
  end
end
