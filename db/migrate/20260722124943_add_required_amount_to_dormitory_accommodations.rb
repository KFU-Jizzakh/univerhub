class AddRequiredAmountToDormitoryAccommodations < ActiveRecord::Migration[8.1]
  def change
    add_column :dormitory_accommodations, :required_amount, :decimal, precision: 10, scale: 2, null: false, default: 0
  end
end
