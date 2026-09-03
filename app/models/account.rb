class Account < ApplicationRecord
  has_many :customers, dependent: :destroy
  has_many :quotes,    dependent: :destroy
  has_many :events,    dependent: :destroy
  has_one  :cadence,   dependent: :destroy
  has_one  :demo_state, dependent: :destroy
  has_many :messages,  class_name: "Cadence::Message", dependent: :destroy

  validates :name, :timezone, presence: true

  def ingest_events!(rows, now: Clock.now)
    stored = Event.ingest!(self, rows)
    Cadence::SweepJob.perform_later(cadence, now: now)
    stored
  end
end
