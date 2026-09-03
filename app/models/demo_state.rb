class DemoState < ApplicationRecord
  belongs_to :account

  validates :current_at, presence: true
  validates :event_cursor, numericality: { greater_than_or_equal_to: 0 }
end
