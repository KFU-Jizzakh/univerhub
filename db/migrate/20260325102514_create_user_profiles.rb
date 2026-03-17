class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :first_name
      t.string :last_name
      t.text :summary

      t.timestamps
    end
  end
end
