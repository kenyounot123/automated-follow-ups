class MessagesController < ApplicationController
  def index
    @messages = @account.messages.pending.includes(:quote, :customer, :cadence_step).newest_first
    @recent = @account.messages.where.not(status: :draft)
                      .includes(:quote).order(updated_at: :desc).limit(10)
  end
end
