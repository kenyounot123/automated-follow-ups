class CreateDemoStates < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_states do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.datetime :current_at, null: false
      t.integer :event_cursor, null: false, default: 0
      t.timestamps

      t.check_constraint "event_cursor >= 0", name: "demo_states_event_cursor_non_negative"
    end
  end
end
