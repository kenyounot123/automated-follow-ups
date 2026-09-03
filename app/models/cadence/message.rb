class Cadence::Message < ApplicationRecord
  enum :status, {
    draft: "draft",
    approved: "approved",
    sent: "sent",
    denied: "denied",
    failed: "failed"
  }

  belongs_to :account
  belongs_to :cadence_step, class_name: "Cadence::Step"
  belongs_to :quote
  belongs_to :customer

  has_one :cadence, through: :cadence_step

  validates :body, :reason, presence: true

  scope :pending,  -> { draft }
  scope :outbound, -> { where(status: statuses.values_at("approved", "sent")) }
  scope :newest_first, -> { order(score: :desc, id: :asc) }

  # Approval is an atomic conditional transition, not an index check.
  #
  # The partial unique index cannot catch two requests approving the *same* draft
  # row: both UPDATE one row, neither INSERTs, so nothing conflicts and both would
  # enqueue a send. Gating on the row actually changing means only one request ever
  # gets to deliver.
  def approve!(now: Clock.now)
    changed = self.class.where(id: id, status: :draft)
                        .update_all(status: :approved, approved_at: now, updated_at: now)
    return false if changed.zero?

    reload
    DeliverMessageJob.perform_later(self)
    true
  end

  def deny!(now: Clock.now)
    changed = self.class.where(id: id, status: :draft)
                        .update_all(status: :denied, denied_at: now, updated_at: now)
    changed.positive?.tap { reload if changed.positive? }
  end

  # Delivery is mocked. The send is recorded as a message_sent event so outbound
  # history has exactly one source of truth: the cadence reads our own sends the
  # same way it reads the six that arrived in the seed file.
  def deliver!(now: Clock.now)
    return false unless approved?

    transaction do
      update!(status: :sent, sent_at: now)
      Event.ingest!(account, [ {
        event_id: "cadence-message-#{id}",
        type: "message_sent",
        quote_id: quote.external_id,
        timestamp: now.utc.iso8601,
        channel: cadence_step.channel,
        direction: "outbound"
      } ])
    end
    true
  end

  def to_partial_path = "messages/message"

  # Retries are finite. Without this a permanently undeliverable message would sit
  # at "approved" forever, looking sent.
  def fail!(error, now: Clock.now)
    update!(status: :failed, delivery_error: error.message.truncate(500), updated_at: now)
  end
end
