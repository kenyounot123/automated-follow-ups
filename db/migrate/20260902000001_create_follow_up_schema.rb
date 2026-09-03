class CreateFollowUpSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :timezone, null: false, default: "America/New_York"
      t.timestamps
    end

    create_table :customers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone, null: false
      t.timestamps

      t.index %i[account_id phone], unique: true
    end

    create_table :quotes do |t|
      t.references :account,  null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string   :external_id, null: false
      t.string   :tech_name,   null: false
      t.integer  :amount_cents, null: false
      t.string   :status, null: false, default: "open"
      t.datetime :quoted_at, null: false

      # What the source system told us, as opposed to what the event log shows.
      t.string   :reported_status, null: false
      t.datetime :reported_last_contact_at

      # Signals, rebuilt wholesale from the event log. Never incrementally folded.
      t.datetime :last_viewed_at
      t.integer  :view_count, null: false, default: 0
      t.datetime :last_customer_reply_at
      t.datetime :last_outbound_at
      t.integer  :outbound_count, null: false, default: 0
      t.datetime :accepted_at

      t.timestamps

      t.index %i[account_id external_id], unique: true
      t.index :status

      t.check_constraint "amount_cents >= 0", name: "quotes_amount_non_negative"
      t.check_constraint "status IN ('open','accepted','dismissed')", name: "quotes_status_enum"
      t.check_constraint "view_count >= 0 AND outbound_count >= 0", name: "quotes_counts_non_negative"
    end

    create_table :events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :quote,   null: false, foreign_key: true
      t.string   :external_event_id, null: false
      t.string   :event_type, null: false
      t.datetime :occurred_at, null: false
      t.string   :channel
      t.string   :direction
      t.json     :payload
      t.timestamps

      # The idempotency guardrail. Replaying the same file is a no-op.
      t.index %i[account_id external_event_id], unique: true
      t.index %i[quote_id occurred_at]

      t.check_constraint <<~SQL.squish, name: "events_type_enum"
        event_type IN ('quote_sent','quote_viewed','customer_replied','message_sent','quote_accepted')
      SQL
    end

    create_table :cadences do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :min_amount_cents,       null: false, default: 50_000
      t.integer :max_age_days,           null: false, default: 30
      t.integer :viewed_recently_hours,  null: false, default: 48
      t.integer :big_quote_amount_cents, null: false, default: 1_000_000
      t.integer :stale_contact_days,     null: false, default: 4
      t.timestamps

      t.index :account_id, unique: true, where: "active", name: "index_cadences_one_active_per_account"
    end

    create_table :cadence_steps do |t|
      t.references :cadence, null: false, foreign_key: true
      t.integer :position,    null: false
      t.integer :delay_hours, null: false
      t.string  :channel, null: false, default: "sms"
      t.string  :label,   null: false
      t.text    :prompt_template, null: false
      t.timestamps

      t.index %i[cadence_id position], unique: true

      t.check_constraint "position > 0",     name: "cadence_steps_position_positive"
      t.check_constraint "delay_hours >= 0", name: "cadence_steps_delay_non_negative"
      t.check_constraint "channel IN ('sms','email')", name: "cadence_steps_channel_enum"
    end

    create_table :cadence_messages do |t|
      t.references :account,      null: false, foreign_key: true
      t.references :cadence_step, null: false, foreign_key: true
      t.references :quote,        null: false, foreign_key: true
      t.references :customer,     null: false, foreign_key: true
      t.string  :status, null: false, default: "draft"
      t.string  :reason, null: false
      t.decimal :score, precision: 10, scale: 2, null: false, default: 0
      t.text    :body, null: false
      t.datetime :drafted_at, null: false
      t.datetime :approved_at
      t.datetime :sent_at
      t.datetime :denied_at
      t.text     :delivery_error
      t.timestamps

      t.index :quote_id, unique: true, where: "status = 'draft'",
              name: "index_cadence_messages_one_draft_per_quote"

      # This is what makes a step unrepeatable once it has gone out.
      t.index %i[customer_id quote_id cadence_step_id], unique: true,
              where: "status IN ('approved','sent')",
              name: "index_cadence_messages_one_send_per_step"

      t.check_constraint "status IN ('draft','approved','sent','denied','failed')",
                         name: "cadence_messages_status_enum"
    end
  end
end
