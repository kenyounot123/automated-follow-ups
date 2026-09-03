class OnlySuccessfulSendsConsumeSteps < ActiveRecord::Migration[8.1]
  def change
    remove_index :cadence_messages, %i[customer_id quote_id cadence_step_id],
                 unique: true, where: "status IN ('approved','sent','denied')",
                 name: "index_cadence_messages_one_decision_per_step"

    add_index :cadence_messages, %i[customer_id quote_id cadence_step_id],
              unique: true, where: "status IN ('approved','sent')",
              name: "index_cadence_messages_one_send_per_step"
  end
end
