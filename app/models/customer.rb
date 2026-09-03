class Customer < ApplicationRecord
  belongs_to :account
  has_many :quotes, dependent: :destroy
  has_many :messages, class_name: "Cadence::Message", dependent: :destroy

  validates :name, :phone, presence: true
  validates :phone, uniqueness: { scope: :account_id }
end
