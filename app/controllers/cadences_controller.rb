class CadencesController < ApplicationController
  def edit
  end

  def update
    if @cadence.update(cadence_params)
      redirect_to root_path, notice: "Cadence updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def cadence_params
      attributes = params.require(:cadence).permit(
        :min_amount_dollars, :max_age_days, :viewed_recently_hours,
        :big_quote_threshold_dollars, :stale_contact_days
      )
      if attributes.key?(:min_amount_dollars)
        attributes[:min_amount_cents] = dollars_to_cents(attributes.delete(:min_amount_dollars))
      end
      if attributes.key?(:big_quote_threshold_dollars)
        attributes[:big_quote_amount_cents] = dollars_to_cents(attributes.delete(:big_quote_threshold_dollars))
      end
      attributes
    end

    def dollars_to_cents(value)
      return if value.blank?

      (BigDecimal(value.to_s) * 100).round(0).to_i
    rescue ArgumentError
      nil
    end
end
