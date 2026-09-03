class IncludeDeniedInSendGuardrail < ActiveRecord::Migration[8.1]
  # Denying a draft used to mean nothing durable: the next scheduled run saw no
  # sent message for that step and drafted it again. Folding 'denied' into the
  # guardrail makes a declined step unrepeatable at the database level, the same
  # way a sent one already was.
  def change
    remove_index :cadence_messages, %i[customer_id quote_id cadence_step_id],
                 unique: true, where: "status IN ('approved','sent')",
                 name: "index_cadence_messages_one_send_per_step"

    add_index :cadence_messages, %i[customer_id quote_id cadence_step_id],
              unique: true, where: "status IN ('approved','sent','denied')",
              name: "index_cadence_messages_one_decision_per_step"
  end
end
