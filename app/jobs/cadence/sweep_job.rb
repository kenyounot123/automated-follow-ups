class Cadence::SweepJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(cadence, now: Clock.now)
    cadence.sweep!(now: now)
  end
end
