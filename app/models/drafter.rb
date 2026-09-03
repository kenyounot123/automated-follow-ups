# Writes the message body. Deliberately not an LLM call.
#
# Output is deterministic, seeded on the quote's external id, so the same quote
# always produces the same copy and integration tests can assert on it.
class Drafter
  # Openers are sentence continuations: every template places them after "Hi <name>, ".
  OPENERS = {
    "viewed_no_reply" => [
      "saw you had a look at the quote",
      "noticed you opened the quote"
    ],
    "big_quote_stale" => [
      "wanted to make sure this one didn't slip through",
      "circling back on your quote"
    ],
    "never_viewed" => [
      "not sure the quote reached you",
      "checking the quote actually landed"
    ],
    "going_cold" => [
      "following up on your quote",
      "checking in on the quote"
    ]
  }.freeze

  CLOSERS = {
    "viewed_no_reply" => "Happy to walk through any of it - any questions?",
    "big_quote_stale" => "Glad to talk through the numbers whenever suits.",
    "never_viewed"    => "Want me to resend the link?",
    "going_cold"      => "Just reply here if you'd like to move ahead."
  }.freeze

  def draft(quote:, step:, reason:)
    reason = reason.to_s
    rng = Random.new(seed_for(quote, step))
    opener = OPENERS.fetch(reason, OPENERS["going_cold"]).sample(random: rng)

    format(
      step.prompt_template,
      opener: opener,
      customer: quote.customer.name.split.first,
      tech: quote.tech_name,
      amount: ActiveSupport::NumberHelper.number_to_currency(quote.amount_cents / 100.0, precision: 0),
      closer: CLOSERS.fetch(reason, CLOSERS["going_cold"])
    )
  end

  private
    def seed_for(quote, step)
      Digest::MD5.hexdigest("#{quote.external_id}:#{step.position}").to_i(16)
    end
end
