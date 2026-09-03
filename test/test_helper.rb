ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Seeding is the fixture here: the real db/seed files are the thing under test,
    # so loading them keeps the suite honest about the data it has to survive.
    def seed!
      Account.destroy_all
      load Rails.root.join("db/seeds.rb")
      Account.first!
    end

    def seed_events
      Rails.root.join("db/seed/events.jsonl").each_line.filter_map do |line|
        ::JSON.parse(line) if line.strip.present?
      end
    end

    # Every derived value, ordered, for comparing one ingestion against another.
    def signals_for(account)
      account.quotes.order(:external_id).pluck(
        :external_id, :status, :last_viewed_at, :view_count,
        :last_customer_reply_at, :last_outbound_at, :outbound_count, :accepted_at
      )
    end

    def demo_now = Rails.configuration.x.demo_now
  end
end
