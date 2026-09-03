class Cadence::Step < ApplicationRecord
  belongs_to :cadence
  has_many :messages, class_name: "Cadence::Message", foreign_key: :cadence_step_id, dependent: :destroy

  validates :position, numericality: { greater_than: 0 }
  validates :delay_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :label, :prompt_template, presence: true
  validates :channel, inclusion: { in: %w[sms email] }
  validates :position, uniqueness: { scope: :cadence_id }

  # Steps carry the only timing rule. A single global cooldown alongside per-step
  # delays would be two knobs governing one decision.
  def due?(since, now:)
    since.blank? || now >= since + delay_hours.hours
  end
end
