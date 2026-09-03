class DeliverMessageJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.fail!(error)
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(message)
    message.deliver!
  end
end
