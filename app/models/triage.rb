# Read-only follow-up policy.
#
# Given a cadence and a "now", produces a ranked list of quotes that deserve a
# follow-up, each with the reason it surfaced. Writes nothing: the same call can run
# on every page load, and nothing happens to a customer until a human approves a
# draft. Everything that decides urgency lives here in one place.
class Triage
  WEIGHT = {
    "viewed_no_reply" => 100,
    "big_quote_stale" => 80,
    "never_viewed"    => 60,
    "going_cold"      => 40
  }.freeze

  NEVER_VIEWED_AFTER = 24.hours

  Candidate = Struct.new(:quote, :reason, :score, :step, :message, keyword_init: true)

  attr_reader :cadence, :now

  def initialize(cadence, now: Clock.now)
    @cadence = cadence
    @now = now
  end

  def candidates
    @candidates ||= scope.filter_map { |quote| candidate_for(quote) }
                         .sort_by { |c| [ -c.score, c.quote.external_id ] }
  end

  # Drafting runs on a schedule, so a candidate becomes a draft almost immediately.
  # The ranked view has to include those or it would always look empty.
  def queue
    @queue ||= (drafted_candidates + candidates).sort_by { |c| [ -c.score, c.quote.external_id ] }
  end

  # The customer wrote to us and nobody answered. These are surfaced for a human
  # rather than drafted: a templated nudge is the wrong reply to a real message.
  def needs_reply
    @needs_reply ||= scope.select(&:awaiting_our_reply?)
                          .sort_by { |q| [ -q.amount_cents, q.external_id ] }
  end

  private
    def drafted_candidates
      cadence.account.messages.pending.includes(:quote, :customer, :cadence_step).map do |message|
        Candidate.new(quote: message.quote, reason: message.reason, score: message.score,
                      step: message.cadence_step, message: message)
      end
    end

    def scope
      @scope ||= cadence.account.quotes.open_quotes.includes(:customer, :messages).to_a
    end

    def candidate_for(quote)
      return if quote.awaiting_our_reply?
      return if quote.amount_cents < cadence.min_amount_cents
      return if quote.quoted_at < now - cadence.max_age_days.days

      step = cadence.step_after(touches_used(quote))
      return if step.nil?
      return unless step.due?(last_decision_at(quote), now: now)
      return if already_handled?(quote, step)

      reason = reason_for(quote)
      return if reason.nil?

      Candidate.new(quote: quote, reason: reason, step: step, score: score_for(quote, reason))
    end

    def touches_used(quote)
      quote.outbound_count
    end

    def last_decision_at(quote)
      [ quote.last_outbound_at, quote.quoted_at ].compact.max
    end

    # Drafts and in-flight deliveries reserve the step. Only a successful send
    # advances it; failed or denied messages may be retried.
    def already_handled?(quote, step)
      quote.messages.any? do |message|
        message.cadence_step_id == step.id && (message.draft? || message.approved?)
      end
    end

    def reason_for(quote)
      if viewed_recently?(quote) && quote.last_customer_reply_at.blank? && no_outbound_since_view?(quote)
        "viewed_no_reply"
      elsif quote.amount_cents >= cadence.big_quote_amount_cents && stale?(quote)
        "big_quote_stale"
      elsif quote.view_count.zero? && quote.quoted_at <= now - NEVER_VIEWED_AFTER
        "never_viewed"
      elsif stale?(quote)
        "going_cold"
      end
    end

    def viewed_recently?(quote)
      quote.last_viewed_at.present? && quote.last_viewed_at >= now - cadence.viewed_recently_hours.hours
    end

    def no_outbound_since_view?(quote)
      quote.last_outbound_at.blank? || quote.last_viewed_at > quote.last_outbound_at
    end

    def stale?(quote)
      contact = quote.effective_last_contact_at
      contact.blank? || contact <= now - cadence.stale_contact_days.days
    end

    # Repeat viewing lifts the score rather than forming its own reason, so one
    # expression decides priority.
    def score_for(quote, reason)
      amount_factor = Math.log10([ quote.amount_cents / 100.0, 10.0 ].max)
      recency_decay = 1.0 / (1.0 + days_since_signal(quote) / 7.0)
      view_bonus    = [ 1.0 + 0.15 * [ quote.view_count - 1, 0 ].max, 1.5 ].min

      (WEIGHT.fetch(reason) * amount_factor * recency_decay * view_bonus).round(2)
    end

    def days_since_signal(quote)
      last = [ quote.last_viewed_at, quote.effective_last_contact_at, quote.quoted_at ].compact.max
      [ (now - last) / 1.day, 0.0 ].max
    end
end
