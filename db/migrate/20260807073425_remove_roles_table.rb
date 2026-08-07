class RemoveRolesTable < ActiveRecord::Migration[8.1]
  # PURPOSE: Replace role join-table with a denormalized role_name string on user_roles, then drop the roles table
  # SPECIFICATION: SPEC-CORE-02

  def up
    add_column :user_roles, :role_name, :string

    execute <<~SQL.squish
      UPDATE user_roles
      SET role_name = (SELECT roles.name FROM roles WHERE roles.id = user_roles.role_id)
    SQL

    change_column_null :user_roles, :role_name, false

    remove_reference :user_roles, :role, index: true
    drop_table :roles

    add_index :user_roles, [ :user_id, :role_name ], unique: true
    add_index :user_roles, :role_name
  end

  def down
    create_table :roles do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :roles, :name, unique: true

    add_reference :user_roles, :role, foreign_key: true, index: true

    execute <<~SQL.squish
      INSERT INTO roles (name, created_at, updated_at)
      SELECT DISTINCT role_name, NOW(), NOW() FROM user_roles
    SQL

    execute <<~SQL.squish
      UPDATE user_roles
      SET role_id = (SELECT roles.id FROM roles WHERE roles.name = user_roles.role_name)
    SQL

    change_column_null :user_roles, :role_id, false

    remove_index :user_roles, name: "index_user_roles_on_user_id_and_role_name"
    remove_index :user_roles, name: "index_user_roles_on_role_name"
    remove_column :user_roles, :role_name
  end
end
