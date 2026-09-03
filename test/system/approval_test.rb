require "application_system_test_case"

# The HTTP tests cannot see whether Turbo actually swaps the row in place, so this
# is the one place a real browser earns its keep.
class ApprovalTest < ApplicationSystemTestCase
  setup do
    seed!
    Cadence::SweepJob.perform_now(Account.first.cadence, now: demo_now)
  end

  test "approving a draft updates the row in place without leaving the page" do
    visit messages_path

    first_draft = find("article", match: :first)
    quote_id = first_draft.find("a").text

    within(first_draft) { click_button "Approve" }

    assert_text "Approved and sending"
    assert_selector "article", text: quote_id
    within("article", text: quote_id) do
      assert_no_button "Approve", wait: 5
    end
    assert_current_path messages_path
  end

  test "denying a draft removes it from the queue" do
    visit messages_path

    before = all("article").size
    within(find("article", match: :first)) { click_button "Deny" }

    assert_text "Draft denied"
    assert_selector "article", count: before - 1
  end
end
