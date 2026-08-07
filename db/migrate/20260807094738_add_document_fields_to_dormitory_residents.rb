class AddDocumentFieldsToDormitoryResidents < ActiveRecord::Migration[8.1]
  # PURPOSE: Add application/contract document numbers to residents, prepared by registrar before settlement
  # SPECIFICATION: SPEC-DORM-03, SPEC-DORM-04

  def change
    add_column :dormitory_residents, :application_number, :string
    add_column :dormitory_residents, :contract_number, :string
  end
end
