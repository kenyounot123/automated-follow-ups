class IngestEventsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(account, rows, now: Clock.now)
    account.ingest_events!(rows, now: now)
  end
end
