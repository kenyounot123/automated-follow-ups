# Safe to run repeatedly: quotes are matched on their external id and event
# ingestion is idempotent, so a second run changes nothing.

seed_dir = Rails.root.join("db/seed")

account = Account.find_or_create_by!(name: "Ridgeline Home Services") do |a|
  a.timezone = "America/New_York"
end

cadence = account.cadence || account.build_cadence(name: "Standard follow-up")
cadence.update!(
  min_amount_cents: 50_000,
  max_age_days: 30,
  viewed_recently_hours: 48,
  big_quote_amount_cents: 1_000_000,
  stale_contact_days: 4
)

[
  { position: 1, delay_hours: 48, channel: "sms", label: "First nudge",
    prompt_template: "Hi %{customer}, %{opener} for %{amount}. %{closer} - %{tech}" },
  { position: 2, delay_hours: 96, channel: "sms", label: "Second nudge",
    prompt_template: "Hi %{customer}, %{opener}. The %{amount} price still stands. %{closer} - %{tech}" },
  { position: 3, delay_hours: 168, channel: "email", label: "Final check-in",
    prompt_template: "Hi %{customer}, %{opener}. Last check on the %{amount} estimate before I close it out. %{closer} - %{tech}" }
].each do |attrs|
  step = cadence.steps.find_or_initialize_by(position: attrs[:position])
  step.update!(attrs)
end

quotes = JSON.parse(seed_dir.join("quotes.json").read)
quotes.each do |row|
  customer = account.customers.find_or_initialize_by(phone: row["customer_phone"])
  customer.update!(name: row["customer_name"])

  quote = account.quotes.find_or_initialize_by(external_id: row["id"])
  quote.assign_attributes(
    customer: customer,
    tech_name: row["tech_name"],
    amount_cents: row["amount"] * 100,
    quoted_at: row["created_at"],
    reported_status: row["status"],
    reported_last_contact_at: row["last_contact_at"]
  )
  quote.status = :open if quote.new_record?
  quote.save!
end

events = seed_dir.join("events.jsonl").each_line.filter_map do |line|
  JSON.parse(line) if line.strip.present?
end

if Rails.env.test?
  stored = Event.ingest!(account, events)
  # Quotes with no events still need their reported status reflected.
  account.quotes.find_each(&:recompute_signals!)
  drafted = 0
else
  replay = Demo::Replay.new(account)
  replay.reset!
  stored = 0
  drafted = 0
end

Rails.env.test? or puts "Seeded #{account.quotes.count} quotes, #{account.customers.count} customers, " \
     "#{account.events.count} events (#{stored} new from #{events.size} lines), " \
     "#{cadence.steps.count} cadence steps, #{drafted} drafts."
