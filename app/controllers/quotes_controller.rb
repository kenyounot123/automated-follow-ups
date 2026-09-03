class QuotesController < ApplicationController
  def show
    @quote = @account.quotes.find_by!(external_id: params[:external_id])
    @events = @quote.events.chronological
    @messages = @quote.messages.order(:drafted_at)
  end
end
