class TriageController < ApplicationController
  def index
    @triage = @cadence.triage(now: now)
    @queue = @triage.queue
    @pending_count = @account.messages.pending.count
  end
end
