class Cadence::StepProposer
  def self.propose(candidate, now: Clock.now)
    quote = candidate.quote
    Cadence::Message.create!(
      account_id: quote.account_id,
      quote: quote,
      customer_id: quote.customer_id,
      cadence_step: candidate.step,
      reason: candidate.reason,
      score: candidate.score,
      body: drafter.draft(quote: quote, step: candidate.step, reason: candidate.reason),
      drafted_at: now
    )
  end

  def self.drafter
    Rails.configuration.x.drafter.to_s.constantize.new
  end
  private_class_method :drafter
end
