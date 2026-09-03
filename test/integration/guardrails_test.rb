require "test_helper"

# The guardrails are in the database, so these tests go at the database, not at the
# validations sitting in front of it.
class GuardrailsTest < ActionDispatch::IntegrationTest
  setup do
    @account = seed!
    @cadence = @account.cadence
    @candidate = @cadence.triage(now: demo_now).candidates.first
  end

  test "a quote cannot hold two pending drafts" do
    Cadence::StepProposer.propose(@candidate, now: demo_now)

    assert_raises ActiveRecord::RecordNotUnique do
      Cadence::StepProposer.propose(@candidate, now: demo_now)
    end
    assert_equal 1, @candidate.quote.messages.pending.count
  end

  test "a step cannot be sent twice for the same quote" do
    sent = Cadence::StepProposer.propose(@candidate, now: demo_now)
    perform_enqueued_jobs { sent.approve!(now: demo_now) }
    assert sent.reload.sent?

    duplicate = Cadence::Message.new(
      account: @account, quote: @candidate.quote, customer: @candidate.quote.customer,
      cadence_step: @candidate.step, reason: @candidate.reason, body: "duplicate",
      drafted_at: demo_now, status: :approved
    )

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "a denied step can be attempted again" do
    denied = Cadence::StepProposer.propose(@candidate, now: demo_now)
    denied.deny!(now: demo_now)

    retry_message = Cadence::Message.new(
      account: @account, quote: @candidate.quote, customer: @candidate.quote.customer,
      cadence_step: @candidate.step, reason: @candidate.reason, body: "retry",
      drafted_at: demo_now, status: :draft
    )

    assert retry_message.save!(validate: false)
  end

  test "an account cannot have two cadences" do
    assert_raises ActiveRecord::RecordNotUnique do
      Cadence.insert!({
        account_id: @account.id, name: "Rival", min_amount_cents: 0, max_age_days: 30,
        viewed_recently_hours: 48, big_quote_amount_cents: 1, stale_contact_days: 1,
        created_at: Time.current, updated_at: Time.current
      })
    end
  end

  test "the same event id cannot be stored twice" do
    event = @account.events.first

    assert_raises ActiveRecord::RecordNotUnique do
      @account.events.insert!({
        quote_id: event.quote_id, external_event_id: event.external_event_id,
        event_type: "quote_viewed", occurred_at: Time.current,
        created_at: Time.current, updated_at: Time.current
      })
    end
  end

  test "a quote cannot have a negative amount" do
    assert_raises ActiveRecord::StatementInvalid do
      @account.quotes.first.update_column(:amount_cents, -1)
    end
  end

  test "a message cannot hold a status outside the enum" do
    message = Cadence::StepProposer.propose(@candidate, now: demo_now)

    assert_raises ActiveRecord::StatementInvalid do
      message.update_column(:status, "hopeful")
    end
  end

  test "two customers cannot share a phone within an account" do
    assert_raises ActiveRecord::RecordNotUnique do
      @account.customers.insert!({
        name: "Impostor", phone: @account.customers.first.phone,
        created_at: Time.current, updated_at: Time.current
      })
    end
  end

  test "one customer may hold follow-ups for two different quotes" do
    # Karen owns Q-1003 and Q-1025. Being chased about each is intended; being
    # chased twice about one is not.
    karen = @account.customers.find_by!(phone: "+19175552003")
    assert_equal 2, karen.quotes.count

    drafted = karen.quotes.filter_map do |quote|
      candidate = @cadence.triage(now: demo_now).candidates.find { |c| c.quote.id == quote.id }
      Cadence::StepProposer.propose(candidate, now: demo_now) if candidate
    end

    assert_equal 2, drafted.size, "each quote gets its own follow-up"
    assert_equal 2, drafted.map(&:quote_id).uniq.size
  end
end
