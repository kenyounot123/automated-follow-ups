class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_account

  private
  def set_account
    @account = Account.first!
    @cadence = @account.cadence
    @demo = Demo::Replay.new(@account)
    @demo.ensure_state!
  end

    def now = Clock.now
end
