require "test_helper"

# The event stream is the source of truth, and it arrives duplicated and unordered.
# These are the properties the rest of the app is allowed to assume.
class EventIngestionTest < ActionDispatch::IntegrationTest
  setup { @account = seed! }

  test "the seed file's duplicate event ids collapse to one row each" do
    lines = seed_events
    assert_equal 88, lines.size, "fixture changed"
    assert_equal 82, lines.map { |e| e["event_id"] }.uniq.size, "fixture changed"

    assert_equal 82, @account.events.count
  end

  test "replaying the same file changes nothing" do
    before = signals_for(@account)

    assert_no_difference -> { @account.events.count } do
      Event.ingest!(@account, seed_events)
    end
    assert_equal before, signals_for(@account)
  end

  test "signals are identical no matter what order events arrive in" do
    baseline = signals_for(@account)

    5.times do |i|
      Event.ingest!(@account, seed_events.shuffle)
      assert_equal baseline, signals_for(@account), "diverged on shuffle #{i + 1}"
    end
    assert_equal 82, @account.events.count
  end

  test "an accepted quote is not reopened by events that arrive after acceptance" do
    quote = @account.quotes.find_by!(external_id: "Q-1004")

    assert_equal "accepted", quote.status
    assert quote.accepted_at.present?
    assert quote.last_viewed_at > quote.accepted_at,
           "fixture should have a view after acceptance"
  end

  test "a quote accepted with no acceptance event is still accepted" do
    # Q-1017 is the largest quote in the set and is marked accepted by the source
    # system, but no quote_accepted event exists for it anywhere in the file.
    # Deriving acceptance from events alone would put a won deal into triage.
    quote = @account.quotes.find_by!(external_id: "Q-1017")

    assert_nil quote.accepted_at
    assert_equal "accepted", quote.status
    assert_not_includes @account.cadence.triage(now: demo_now).candidates.map { |c| c.quote.external_id },
                        "Q-1017"
  end

  test "a dismissed quote stays dismissed" do
    assert_equal "dismissed", @account.quotes.find_by!(external_id: "Q-1009").status
  end

  test "effective contact keeps whichever source is newer" do
    # The snapshot records contact that emitted no event; the events record contact
    # the snapshot never learned about. On the seed data they disagree both ways.
    snapshot_only = @account.quotes.find_by!(external_id: "Q-1003")
    assert snapshot_only.reported_last_contact_at.present?
    assert_nil snapshot_only.last_customer_reply_at
    assert_equal snapshot_only.reported_last_contact_at, snapshot_only.effective_last_contact_at

    events_newer = @account.quotes.find_by!(external_id: "Q-1002")
    latest_event = [ events_newer.last_customer_reply_at, events_newer.last_outbound_at ].compact.max
    assert latest_event > events_newer.reported_last_contact_at
    assert_equal latest_event, events_newer.effective_last_contact_at
  end

  test "events for an unknown quote are skipped rather than inventing one" do
    assert_no_difference [ -> { @account.events.count }, -> { @account.quotes.count } ] do
      Event.ingest!(@account, [ {
        "event_id" => "orphan-1", "type" => "quote_viewed",
        "quote_id" => "Q-9999", "timestamp" => "2026-08-16T00:00:00Z"
      } ])
    end
  end
end
