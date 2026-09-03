class ApprovalsController < ApplicationController
  before_action :set_message

  def create
    @message.approve!(now: now)
    respond_with_message "Approved and sending to #{@message.customer.name}."
  end

  def destroy
    @message.deny!(now: now)
    respond_with_message "Draft denied."
  end

  private
    def set_message
      @message = @account.messages.find(params[:message_id])
    end

    def respond_with_message(notice)
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to messages_path, notice: notice }
      end
    end
end
