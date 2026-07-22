class CreateDormitoryReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :dormitory_receipts do |t|
      t.references :accommodation, null: false, foreign_key: { to_table: :dormitory_accommodations }
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :paid_at, null: false
      t.text :comment
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dormitory_receipts, :discarded_at
  end
end
