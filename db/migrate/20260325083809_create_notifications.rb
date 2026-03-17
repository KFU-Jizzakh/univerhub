class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :notifiable_type
      t.bigint :notifiable_id
      t.string :action, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :notifiable_type, :notifiable_id ]
    add_index :notifications, [ :recipient_id, :read_at ]
  end
end
