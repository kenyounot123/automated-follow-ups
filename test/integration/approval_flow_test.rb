require "test_helper"

class ApprovalFlowTest < ActionDispatch::IntegrationTest
  setup { @account = seed! }

  # Drafting is the scheduler's job now, so tests drive it the same way it runs.
  def draft!
    Cadence::SweepJob.perform_now(@account.cadence, now: demo_now)
  end

  test "triage lists candidates with their reasons and never mentions a won quote" do
    get root_path

    assert_response :success
    assert_select "h1", /Follow-up triage/
    assert_match "Q-1026", response.body
    assert_match "viewed no reply", response.body
    assert_no_match(/Q-1017/, response.body)
    assert_no_match(/Q-1004/, response.body)
  end

  test "triage shows quotes owed a human reply separately" do
    get root_path

    assert_response :success
    assert_select "h2", /Needs a human reply/
  end

  test "drafting is idempotent" do
    Cadence::Message.pending.delete_all
    assert_difference -> { Cadence::Message.pending.count }, +20 do
      draft!
    end

    assert_no_difference -> { Cadence::Message.pending.count } do
      draft!
    end
  end

  test "a drafted message can be approved and is sent" do
    draft!
    message = @account.messages.pending.newest_first.first

    get messages_path
    assert_response :success
    assert_match message.body, response.body

    perform_enqueued_jobs do
      post message_approval_path(message), as: :turbo_stream
    end

    assert_response :success
    assert message.reload.sent?
    assert message.sent_at.present?
  end

  test "approving records the send in the quote's own history" do
    draft!
    message = @account.messages.pending.newest_first.first
    quote = message.quote

    assert_difference -> { quote.reload.outbound_count }, +1 do
      perform_enqueued_jobs { post message_approval_path(message), as: :turbo_stream }
    end
    assert_equal message.reload.sent_at, quote.reload.last_outbound_at
  end

  test "a drafted message can be denied and leaves the queue" do
    draft!
    message = @account.messages.pending.newest_first.first

    assert_no_enqueued_jobs only: DeliverMessageJob do
      delete message_approval_path(message), as: :turbo_stream
    end

    assert_response :success
    assert message.reload.denied?
    assert_empty @account.messages.pending.where(id: message.id)
  end

  test "the quote page shows the event timeline" do
    get quote_path(@account.quotes.find_by!(external_id: "Q-1012"))

    assert_response :success
    assert_select "h1", /Q-1012/
    assert_match "quote viewed", response.body
  end

  test "the cadence rules can be edited" do
    get edit_cadence_path
    assert_response :success
    assert_select "label[for='cadence_min_amount_dollars']", text: "Minimum quote amount"
    assert_select "input#cadence_min_amount_dollars[value='500.00']"
    assert_select "input#cadence_big_quote_threshold_dollars[value='10000.00']"
    assert_select "label[for='cadence_viewed_recently_hours']", text: "Recent quote-view window (hours)"
    assert_match "A recent view suggests the customer may still be considering the quote.", response.body

    patch cadence_path, params: { cadence: { min_amount_dollars: "1000.00" } }
    assert_redirected_to root_path
    assert_equal 100_000, @account.cadence.reload.min_amount_cents
  end
end
