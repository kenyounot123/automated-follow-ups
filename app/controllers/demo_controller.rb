class DemoController < ApplicationController
  def reset
    @demo.reset!
    redirect_to root_path, notice: "Demo reset. The event stream is ready to replay."
  end

  def next_event
    result = @demo.next_event_and_cycle!
    notice =
      if result[:event]
        "Queued #{result[:event].fetch("type").tr("_", " ")}; ingestion will trigger a cadence sweep."
      else
        "The demo event stream is complete."
      end
    redirect_to root_path, notice: notice
  end

  def cycle
    result = @demo.run_cycle!
    redirect_to root_path,
                notice: "Cycle queued: #{result[:queued]} event(s) released for ingestion and reconciliation."
  end

  def advance
    hours = params.fetch(:hours, 24).to_i
    unless [ 24, 96, 168 ].include?(hours)
      redirect_to root_path, alert: "Choose a supported demo interval."
      return
    end

    result = @demo.advance!(hours: hours)
    redirect_to root_path,
                notice: "Advanced #{hours / 24} day(s): #{result[:queued]} event(s) released for ingestion and reconciliation."
  end
end
