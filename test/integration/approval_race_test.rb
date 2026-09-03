require "test_helper"

# The partial unique index cannot protect approval on its own: two requests
# approving the same draft both UPDATE one row and neither INSERTs, so nothing
# conflicts. The guard is the conditional transition, and what must hold is that
# only one delivery happens, whatever the database chooses to raise.
class ApprovalRaceTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @account = seed!
    @message = Cadence::StepProposer.propose(@account.cadence.triage(now: demo_now).candidates.first, now: demo_now)
  end

  teardown { Account.destroy_all }

  test "a double-clicked approve sends exactly once" do
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Concurrent::Array.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          copy = Cadence::Message.find(@message.id)
          barrier.wait(5)
          results << (copy.approve!(now: demo_now) rescue false)
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, results.count(true), "exactly one request may win the approval"
    assert @message.reload.approved?
    assert_equal 1, enqueued_jobs.count { |j| j["job_class"] == "DeliverMessageJob" },
                 "only the winning request may enqueue a send"
  end

  test "approving an already-approved draft is refused" do
    assert @message.approve!(now: demo_now)
    assert_not @message.approve!(now: demo_now), "a second approval must not send again"
  end

  test "denying an already-approved draft is refused" do
    assert @message.approve!(now: demo_now)
    assert_not @message.deny!(now: demo_now)
    assert @message.reload.approved?
  end

  test "a permanently undeliverable message is recorded as failed, not left looking sent" do
    @message.approve!(now: demo_now)

    @message.fail!(StandardError.new("carrier rejected the number"))

    assert @message.reload.failed?
    assert_match "carrier rejected", @message.delivery_error
    assert_nil @message.sent_at
  end

  test "delivering twice does not write a second outbound event" do
    @message.approve!(now: demo_now)
    quote = @message.quote

    assert_difference -> { quote.reload.outbound_count }, 1 do
      @message.deliver!(now: demo_now)
    end
    assert_no_difference -> { quote.reload.outbound_count } do
      @message.deliver!(now: demo_now)
    end
  end
end
