class AddActiveRoleToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :active_role, :string
  end
end
