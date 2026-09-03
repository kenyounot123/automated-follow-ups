module ApplicationHelper
  REASON_STYLES = {
    "viewed_no_reply" => "bg-brand-600 text-white",
    "big_quote_stale" => "bg-accent-100 text-accent-600",
    "never_viewed"    => "bg-brand-100 text-brand-800",
    "going_cold"      => "bg-slate-100 text-ink-soft"
  }.freeze

  STATUS_STYLES = {
    "draft"    => "bg-slate-100 text-ink-soft",
    "approved" => "bg-brand-100 text-brand-800",
    "sent"     => "bg-emerald-100 text-emerald-800",
    "denied"   => "bg-slate-100 text-slate-400",
    "failed"   => "bg-red-100 text-red-800"
  }.freeze

  def nav_link_to(name, path)
    active = current_page?(path)
    link_to name, path,
            class: "rounded-md px-3 py-1.5 font-medium #{active ? "bg-white text-brand-700" : "text-brand-100 hover:bg-brand-500 hover:text-white"}"
  end

  def reason_chip(reason)
    tag.span reason.to_s.tr("_", " "),
             class: "inline-flex rounded-full px-2 py-0.5 text-xs font-medium #{REASON_STYLES.fetch(reason.to_s, "bg-slate-200 text-slate-700")}"
  end

  def status_chip(status)
    tag.span status,
             class: "inline-flex rounded-full px-2 py-0.5 text-xs font-medium #{STATUS_STYLES.fetch(status.to_s, "bg-slate-200")}"
  end

  def money(cents)
    number_to_currency(cents / 100.0, precision: 0)
  end

  # Measured against the demo clock. time_ago_in_words would compare to the wall
  # clock and report every seeded quote as weeks old.
  def when_ago(time)
    return "never" if time.blank?

    "#{distance_of_time_in_words(time, Clock.now)} ago"
  end
end
