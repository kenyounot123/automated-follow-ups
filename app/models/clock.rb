# The seed events end 2026-08-16, so against a real clock every quote in the demo
# is weeks stale and the policy fires uniformly. Pinning the clock keeps the
# fixture meaningful. Triage always takes an explicit `now:` so tests never
# depend on this.
module Clock
  def self.now
    DemoState.first&.current_at || Rails.configuration.x.demo_now || Time.current
  end

  def self.pinned?
    DemoState.exists? || Rails.configuration.x.demo_now.present?
  end
end
