class MakeActorIdNullableInOutboxEvents < ActiveRecord::Migration[8.1]
  def change
    change_column_null :outbox_events, :actor_id, true
  end
end
