require "test_helper"

# Triage is a pure function of (quotes, events, cadence, now). It writes nothing,
# and the same inputs must always produce the same ranked list.
class TriageTest < ActionDispatch::IntegrationTest
  setup do
    @account = seed!
    @cadence = @account.cadence
    @triage = @cadence.triage(now: demo_now)
  end

  def external_ids(candidates) = candidates.map { |c| c.quote.external_id }

  test "triage writes nothing" do
    assert_no_difference [ -> { Cadence::Message.count }, -> { Event.count }, -> { Quote.count } ] do
      @triage.candidates
      @triage.needs_reply
    end
  end

  test "ranking is deterministic across runs" do
    first  = external_ids(@cadence.triage(now: demo_now).candidates)
    second = external_ids(@cadence.triage(now: demo_now).candidates)

    assert_equal first, second
    assert_equal first, first.uniq, "a quote must not appear twice"
  end

  test "the hottest large quote leads the queue" do
    top = @triage.candidates.first

    assert_equal "Q-1026", top.quote.external_id
    assert_equal "viewed_no_reply", top.reason
    assert_equal 2_200_000, top.quote.amount_cents
  end

  test "candidates are ordered by score descending" do
    scores = @triage.candidates.map(&:score)
    assert_equal scores.sort.reverse, scores
  end

  test "terminal quotes never surface" do
    surfaced = external_ids(@triage.candidates) + @triage.needs_reply.map(&:external_id)

    %w[Q-1004 Q-1017 Q-1009].each do |id|
      assert_not_includes surfaced, id, "#{id} is terminal and must not be chased"
    end
  end

  test "quotes below the cadence minimum never surface" do
    surfaced = external_ids(@triage.candidates)

    %w[Q-1018 Q-1028].each { |id| assert_not_includes surfaced, id }
    assert @account.quotes.find_by(external_id: "Q-1018").amount_cents < @cadence.min_amount_cents
  end

  test "a customer awaiting our reply is handed to a human, not drafted" do
    assert @triage.needs_reply.any?

    @triage.needs_reply.each do |quote|
      assert quote.awaiting_our_reply?
      assert_not_includes external_ids(@triage.candidates), quote.external_id,
                          "#{quote.external_id} owes a human reply and must not be auto-drafted"
    end
  end

  test "every reason is justified by the quote's own signals" do
    @triage.candidates.each do |candidate|
      quote = candidate.quote
      case candidate.reason
      when "viewed_no_reply"
        assert quote.last_viewed_at >= demo_now - @cadence.viewed_recently_hours.hours
        assert_nil quote.last_customer_reply_at
      when "big_quote_stale"
        assert_operator quote.amount_cents, :>=, @cadence.big_quote_amount_cents
      when "never_viewed"
        assert_equal 0, quote.view_count
      when "going_cold"
        assert_operator quote.amount_cents, :<, @cadence.big_quote_amount_cents
      else
        flunk "unexpected reason #{candidate.reason}"
      end
    end
  end

  test "prior outbound messages consume cadence steps" do
    quote = @account.quotes.find_by!(external_id: "Q-1012")
    assert_equal 1, quote.outbound_count

    candidate = @triage.candidates.find { |c| c.quote.external_id == "Q-1012" }
    assert_equal 2, candidate.step.position
  end

  test "a quote whose next step is not yet due waits" do
    quote = @account.quotes.find_by!(external_id: "Q-1019")
    step = @cadence.step_after(quote.outbound_count)

    assert_not step.due?(quote.last_outbound_at, now: demo_now)
    assert_not_includes external_ids(@triage.candidates), "Q-1019"
  end

  test "a quote becomes due once enough time passes" do
    quote = @account.quotes.find_by!(external_id: "Q-1019")
    later = quote.last_outbound_at + @cadence.steps.second.delay_hours.hours + 1.hour

    assert_includes external_ids(@cadence.triage(now: later).candidates), "Q-1019"
  end

  test "an exhausted cadence stops producing candidates" do
    quote = @account.quotes.find_by!(external_id: "Q-1026")
    quote.update!(outbound_count: @cadence.steps.count)

    assert_nil @cadence.step_after(quote.outbound_count)
    assert_not_includes external_ids(@cadence.triage(now: demo_now).candidates), "Q-1026"
  end

  test "denying a draft leaves the same step eligible" do
    candidate = @triage.candidates.first
    message = Cadence::StepProposer.propose(candidate, now: demo_now)
    assert message.deny!(now: demo_now)

    replacement_candidate = @cadence.triage(now: demo_now).candidates.find do |c|
      c.quote == candidate.quote
    end
    assert replacement_candidate
    replacement = Cadence::StepProposer.propose(replacement_candidate, now: demo_now)
    assert replacement.draft?
  end

  test "denying does not advance the cadence" do
    candidate = @triage.candidates.first
    Cadence::StepProposer.propose(candidate, now: demo_now).deny!(now: demo_now)

    later = demo_now + 20.days
    resumed = @cadence.triage(now: later).candidates.find { |c| c.quote.id == candidate.quote.id }

    assert resumed, "denying one message must not retire the quote forever"
    assert_equal candidate.step.position, resumed.step.position
  end

  test "a failed delivery leaves the same step eligible" do
    candidate = @triage.candidates.first
    message = Cadence::StepProposer.propose(candidate, now: demo_now)
    message.fail!(StandardError.new("carrier rejected the number"), now: demo_now)

    retry_candidate = @cadence.triage(now: demo_now).candidates.find do |c|
      c.quote == candidate.quote
    end

    assert retry_candidate
    assert_equal candidate.step.position, retry_candidate.step.position
  end

  test "the database allows another attempt after a denial" do
    candidate = @triage.candidates.first
    Cadence::StepProposer.propose(candidate, now: demo_now).deny!(now: demo_now)

    retry_message = Cadence::Message.new(
      account: @account, quote: candidate.quote, customer: candidate.quote.customer,
      cadence_step: candidate.step, reason: candidate.reason, body: "again",
      drafted_at: demo_now, status: :denied
    )
    assert retry_message.save!(validate: false)
  end

  test "approving a follow-up removes the quote from triage rather than redrafting it" do
    candidate = @triage.candidates.first
    message = Cadence::StepProposer.propose(candidate, now: demo_now)

    perform_enqueued_jobs { message.approve!(now: demo_now) }

    after = @cadence.triage(now: demo_now)
    assert_not_includes external_ids(after.candidates), candidate.quote.external_id,
                        "the send must start the next step's clock, not invite an immediate redraft"
  end
end
