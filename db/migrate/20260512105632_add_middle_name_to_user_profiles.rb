class AddMiddleNameToUserProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :user_profiles, :middle_name, :string
  end
end
