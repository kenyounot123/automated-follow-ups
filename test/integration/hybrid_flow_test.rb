require "test_helper"

class HybridFlowTest < ActionDispatch::IntegrationTest
  setup { @account = seed! }

  test "newly ingested events trigger drafting reconciliation" do
    @account.events.delete_all
    @account.messages.delete_all
    @account.quotes.find_each(&:recompute_signals!)

    perform_enqueued_jobs do
      IngestEventsJob.perform_later(@account, seed_events, now: demo_now)
    end

    assert_equal 82, @account.events.count
    assert_operator @account.messages.pending.count, :>, 0
  end

  test "replaying duplicate events remains idempotent" do
    perform_enqueued_jobs do
      IngestEventsJob.perform_later(@account, seed_events, now: demo_now)
    end
    before = @account.messages.pending.count
    perform_enqueued_jobs do
      IngestEventsJob.perform_later(@account, seed_events, now: demo_now)
    end

    assert_operator before, :>, 0
    assert_equal before, @account.messages.pending.count
  end
end
