class Cadence < ApplicationRecord
  belongs_to :account
  has_many :steps, -> { order(:position) }, class_name: "Cadence::Step", dependent: :destroy
  has_many :messages, through: :steps

  validates :name, presence: true
  validates :min_amount_cents, :big_quote_amount_cents,
            numericality: { greater_than_or_equal_to: 0 }
  validates :max_age_days, :viewed_recently_hours, :stale_contact_days,
            numericality: { greater_than: 0 }

  def triage(now: Clock.now)
    Triage.new(self, now: now)
  end

  # Prior outbound messages consume steps, so a quote the shop already chased twice
  # resumes at step three rather than restarting.
  def step_after(touches_used)
    steps.detect { |step| step.position == touches_used + 1 }
  end

  def sweep!(now: Clock.now)
    triage(now: now).candidates.count do |candidate|
      Cadence::StepProposer.propose(candidate, now: now)
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
