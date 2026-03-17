class CreateOutboxEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :payload, default: {}
      t.integer :record_id
      t.string :record_type
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :outbox_events, [ :record_type, :record_id ]
    add_index :outbox_events, [ :actor_id, :created_at ]
  end
end
