class Event < ApplicationRecord
  TYPES = %w[quote_sent quote_viewed customer_replied message_sent quote_accepted].freeze

  belongs_to :account
  belongs_to :quote

  validates :external_event_id, :event_type, :occurred_at, presence: true
  validates :event_type, inclusion: { in: TYPES }
  validates :external_event_id, uniqueness: { scope: :account_id }

  scope :chronological, -> { order(:occurred_at, :id) }

  # Idempotent: the unique index on (account_id, external_event_id) absorbs repeats,
  # so replaying a file is a no-op. Duplicate ids are first-write-wins; the seed's
  # six duplicates are byte identical, so the distinction is invisible there.
  #
  # Order independent: nothing here reads current state. Every derived value is
  # rebuilt afterwards by Quote#recompute_signals!.
  def self.ingest!(account, rows)
    quote_ids = account.quotes.pluck(:external_id, :id).to_h
    attributes = Array(rows).filter_map { |row| row_attributes(account, row, quote_ids) }
    return 0 if attributes.empty?

    before = account.events.count
    account.events.insert_all(attributes, unique_by: %i[account_id external_event_id])

    Quote.where(id: attributes.pluck(:quote_id).uniq).find_each(&:recompute_signals!)

    account.events.count - before
  end

  def self.row_attributes(account, row, quote_ids)
    row = row.with_indifferent_access
    quote_id = quote_ids[row[:quote_id]]

    # An event for a quote we have never seen. The seed contains none; if one ever
    # arrives, silently inventing a quote from it would be worse than skipping.
    if quote_id.nil?
      Rails.logger.warn("[Event.ingest!] skipping event for unknown quote #{row[:quote_id].inspect}")
      return nil
    end

    now = Time.current
    {
      account_id: account.id,
      quote_id: quote_id,
      external_event_id: row[:event_id],
      event_type: row[:type],
      occurred_at: row[:timestamp],
      channel: row[:channel],
      direction: row[:direction],
      payload: row.to_h,
      created_at: now,
      updated_at: now
    }
  end
  private_class_method :row_attributes
end
