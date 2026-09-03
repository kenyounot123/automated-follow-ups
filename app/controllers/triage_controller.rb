class TriageController < ApplicationController
  def index
    @triage = @cadence.triage(now: now)
    @candidates = @triage.candidates
    @drafts = @triage.queue.select { |candidate| candidate.message.present? }
  end
end
