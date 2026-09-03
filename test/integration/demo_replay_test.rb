require "test_helper"

class DemoReplayTest < ActionDispatch::IntegrationTest
  setup { @account = seed! }

  test "reset starts before the first source event" do
    replay = Demo::Replay.new(@account)

    replay.reset!

    assert_empty @account.events
    assert_equal Time.iso8601(seed_events.min_by { |event| event["timestamp"] }["timestamp"]) - 1.hour,
                 replay.now
    assert_equal 0, replay.ingested_count
  end

  test "advancing time ingests events through the replay job" do
    replay = Demo::Replay.new(@account)
    replay.reset!

    result = nil
    perform_enqueued_jobs { result = replay.advance!(hours: 24) }

    assert_equal 4, result[:queued]
    assert_equal 4, replay.ingested_count
    assert_equal 4, @account.events.count
  end

  test "running the replay to the end produces drafts through triage" do
    replay = Demo::Replay.new(@account)
    replay.reset!

    result = nil
    perform_enqueued_jobs { result = replay.advance!(hours: 24 * 16) }

    assert_equal 82, result[:queued]
    assert_operator @account.messages.pending.count, :>, 0
    assert_equal 82, replay.ingested_count
  end
end
