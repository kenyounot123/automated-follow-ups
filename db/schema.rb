# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_03_000003) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "timezone", default: "America/New_York", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cadence_messages", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "approved_at"
    t.text "body", null: false
    t.integer "cadence_step_id", null: false
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.text "delivery_error"
    t.datetime "denied_at"
    t.datetime "drafted_at", null: false
    t.integer "quote_id", null: false
    t.string "reason", null: false
    t.decimal "score", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "sent_at"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_cadence_messages_on_account_id"
    t.index ["cadence_step_id"], name: "index_cadence_messages_on_cadence_step_id"
    t.index ["customer_id", "quote_id", "cadence_step_id"], name: "index_cadence_messages_one_send_per_step", unique: true, where: "status IN ('approved','sent')"
    t.index ["customer_id"], name: "index_cadence_messages_on_customer_id"
    t.index ["quote_id"], name: "index_cadence_messages_on_quote_id"
    t.index ["quote_id"], name: "index_cadence_messages_one_draft_per_quote", unique: true, where: "status = 'draft'"
    t.check_constraint "status IN ('draft','approved','sent','denied','failed')", name: "cadence_messages_status_enum"
  end

  create_table "cadence_steps", force: :cascade do |t|
    t.integer "cadence_id", null: false
    t.string "channel", default: "sms", null: false
    t.datetime "created_at", null: false
    t.integer "delay_hours", null: false
    t.string "label", null: false
    t.integer "position", null: false
    t.text "prompt_template", null: false
    t.datetime "updated_at", null: false
    t.index ["cadence_id", "position"], name: "index_cadence_steps_on_cadence_id_and_position", unique: true
    t.index ["cadence_id"], name: "index_cadence_steps_on_cadence_id"
    t.check_constraint "channel IN ('sms','email')", name: "cadence_steps_channel_enum"
    t.check_constraint "delay_hours >= 0", name: "cadence_steps_delay_non_negative"
    t.check_constraint "position > 0", name: "cadence_steps_position_positive"
  end

  create_table "cadences", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "big_quote_amount_cents", default: 1000000, null: false
    t.datetime "created_at", null: false
    t.integer "max_age_days", default: 30, null: false
    t.integer "min_amount_cents", default: 50000, null: false
    t.string "name", null: false
    t.integer "stale_contact_days", default: 4, null: false
    t.datetime "updated_at", null: false
    t.integer "viewed_recently_hours", default: 48, null: false
    t.index ["account_id"], name: "index_cadences_on_account_id", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "phone"], name: "index_customers_on_account_id_and_phone", unique: true
    t.index ["account_id"], name: "index_customers_on_account_id"
  end

  create_table "demo_states", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "current_at", null: false
    t.integer "event_cursor", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_demo_states_on_account_id", unique: true
    t.check_constraint "event_cursor >= 0", name: "demo_states_event_cursor_non_negative"
  end

  create_table "events", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "channel"
    t.datetime "created_at", null: false
    t.string "direction"
    t.string "event_type", null: false
    t.string "external_event_id", null: false
    t.datetime "occurred_at", null: false
    t.json "payload"
    t.integer "quote_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "external_event_id"], name: "index_events_on_account_id_and_external_event_id", unique: true
    t.index ["account_id"], name: "index_events_on_account_id"
    t.index ["quote_id", "occurred_at"], name: "index_events_on_quote_id_and_occurred_at"
    t.index ["quote_id"], name: "index_events_on_quote_id"
    t.check_constraint "event_type IN ('quote_sent','quote_viewed','customer_replied','message_sent','quote_accepted')", name: "events_type_enum"
  end

  create_table "quotes", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "account_id", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.string "external_id", null: false
    t.datetime "last_customer_reply_at"
    t.datetime "last_outbound_at"
    t.datetime "last_viewed_at"
    t.integer "outbound_count", default: 0, null: false
    t.datetime "quoted_at", null: false
    t.datetime "reported_last_contact_at"
    t.string "reported_status", null: false
    t.string "status", default: "open", null: false
    t.string "tech_name", null: false
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0, null: false
    t.index ["account_id", "external_id"], name: "index_quotes_on_account_id_and_external_id", unique: true
    t.index ["account_id"], name: "index_quotes_on_account_id"
    t.index ["customer_id"], name: "index_quotes_on_customer_id"
    t.index ["status"], name: "index_quotes_on_status"
    t.check_constraint "amount_cents >= 0", name: "quotes_amount_non_negative"
    t.check_constraint "status IN ('open','accepted','dismissed')", name: "quotes_status_enum"
    t.check_constraint "view_count >= 0 AND outbound_count >= 0", name: "quotes_counts_non_negative"
  end

  add_foreign_key "cadence_messages", "accounts"
  add_foreign_key "cadence_messages", "cadence_steps"
  add_foreign_key "cadence_messages", "customers"
  add_foreign_key "cadence_messages", "quotes"
  add_foreign_key "cadence_steps", "cadences"
  add_foreign_key "cadences", "accounts"
  add_foreign_key "customers", "accounts"
  add_foreign_key "demo_states", "accounts"
  add_foreign_key "events", "accounts"
  add_foreign_key "events", "quotes"
  add_foreign_key "quotes", "accounts"
  add_foreign_key "quotes", "customers"
end
