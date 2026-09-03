class Quote < ApplicationRecord
  enum :status, {
    open: "open",
    accepted: "accepted",
    dismissed: "dismissed"
  }

  belongs_to :account
  belongs_to :customer
  has_many :events, dependent: :destroy
  has_many :messages, class_name: "Cadence::Message", dependent: :destroy

  validates :external_id, :tech_name, :quoted_at, :reported_status, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :external_id, uniqueness: { scope: :account_id }

  scope :open_quotes, -> { open }

  # Rebuilds every derived signal from the whole event log rather than folding the
  # event that just arrived into the current value.
  #
  # This is what makes ingestion order independent: MIN/MAX/COUNT do not care what
  # order the rows were inserted in, so replaying the same events shuffled, twice,
  # or interleaved with newer ones all converge on the same answer.
  def recompute_signals!
    viewed, views, replied, outbound, outbounds, accepted = events.pick(
      Arel.sql("MAX(CASE WHEN event_type = 'quote_viewed' THEN occurred_at END)"),
      Arel.sql("COUNT(CASE WHEN event_type = 'quote_viewed' THEN 1 END)"),
      Arel.sql("MAX(CASE WHEN event_type = 'customer_replied' THEN occurred_at END)"),
      Arel.sql("MAX(CASE WHEN event_type = 'message_sent' THEN occurred_at END)"),
      Arel.sql("COUNT(CASE WHEN event_type = 'message_sent' THEN 1 END)"),
      Arel.sql("MAX(CASE WHEN event_type = 'quote_accepted' THEN occurred_at END)")
    )

    update!(
      last_viewed_at:         parse_time(viewed),
      view_count:             views.to_i,
      last_customer_reply_at: parse_time(replied),
      last_outbound_at:       parse_time(outbound),
      outbound_count:         outbounds.to_i,
      accepted_at:            parse_time(accepted),
      status:                 derived_status(parse_time(accepted))
    )
  end

  # Contact reached us through two channels that disagree: the source system's own
  # snapshot (which records a phone call that emitted no event) and the event log
  # (which records what this system actually observed). On the seed data these
  # disagree on 23 of 30 quotes in both directions, so neither can be dropped.
  def effective_last_contact_at
    [ reported_last_contact_at, last_customer_reply_at, last_outbound_at ].compact.max
  end

  def terminal? = accepted? || dismissed?

  def awaiting_our_reply?
    last_customer_reply_at.present? &&
      (last_outbound_at.blank? || last_customer_reply_at > last_outbound_at)
  end

  def to_param = external_id

  private
    # Acceptance reaches us from either source. Q-1017 in the seed is accepted with
    # no quote_accepted event anywhere, and it is the largest quote in the set, so
    # deriving acceptance from events alone would put an already-won deal at the top
    # of the follow-up queue. Terminal states are sticky: no later event reopens them.
    def derived_status(accepted_at)
      return :accepted if accepted_at.present? || reported_status == self.class.statuses.fetch("accepted")
      return :dismissed if reported_status == self.class.statuses.fetch("dismissed")

      :open
    end

    def parse_time(value)
      return value if value.blank? || value.is_a?(Time)

      Time.find_zone("UTC").parse(value.to_s)
    end
end
