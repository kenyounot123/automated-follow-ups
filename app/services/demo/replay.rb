class Demo::Replay
  SOURCE = Rails.root.join("db/seed/events.jsonl")

  attr_reader :account

  def initialize(account)
    @account = account
  end

  def state
    @state ||= ensure_state!
  end

  def ensure_state!
    return @state if @state

    @state = account.demo_state || account.create_demo_state!(
      current_at: default_time,
      event_cursor: ingested_source_count
    )
  end

  def now
    state.current_at
  end

  def source_count
    source_events.length
  end

  def ingested_count
    state.event_cursor
  end

  def next_event
    source_events[state.event_cursor]
  end

  def reset!
    account.transaction do
      account.messages.delete_all
      account.events.delete_all
      account.quotes.find_each(&:recompute_signals!)
      state.update!(current_at: initial_time, event_cursor: 0)
    end
  end

  def next_event_and_cycle!
    event = next_event
    return { event: nil, queued: 0 } unless event

    state.update!(current_at: [ state.current_at, event_time(event) ].max)
    IngestEventsJob.perform_later(account, [ event ], now: state.current_at)
    state.update!(event_cursor: state.event_cursor + 1)
    { event: event, queued: 1 }
  end

  def advance!(hours:)
    state.update!(current_at: state.current_at + hours.hours)
    run_cycle!
  end

  def run_cycle!
    batch = source_events.drop(state.event_cursor)
                       .take_while { |event| event_time(event) <= state.current_at }

    if batch.any?
      IngestEventsJob.perform_later(account, batch, now: state.current_at)
      state.update!(event_cursor: state.event_cursor + batch.length)
      return { queued: batch.length }
    end

    Cadence::SweepJob.perform_later(account.cadence, now: state.current_at)
    { queued: 0 }
  end

  private

    def source_events
      @source_events ||= SOURCE.each_line.filter_map do |line|
        JSON.parse(line) if line.strip.present?
      end.uniq { |event| event.fetch("event_id") }
        .sort_by { |event| event_time(event) }
    end

    def initial_time
      event_time(source_events.first) - 1.hour
    end

    def default_time
      Rails.configuration.x.demo_now || initial_time
    end

    def ingested_source_count
      ids = account.events.pluck(:external_event_id)
      source_events.count { |event| ids.include?(event.fetch("event_id")) }
    end

    def event_time(event)
      Time.iso8601(event.fetch("timestamp"))
    end
end
