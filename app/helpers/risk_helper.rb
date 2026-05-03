module RiskHelper
  def risk_badge(level)
    config = {
      "high"   => [ "bg-rose-50 text-rose-700 ring-rose-200",   "High Risk" ],
      "medium" => [ "bg-amber-50 text-amber-700 ring-amber-200", "Medium Risk" ],
      "low"    => [ "bg-emerald-50 text-emerald-700 ring-emerald-200", "Low Risk" ],
      nil      => [ "bg-slate-50 text-slate-500 ring-slate-200", "Unknown" ]
    }
    classes, label = config[level&.to_s] || config[nil]
    content_tag(:span, label,
      class: "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 #{classes}")
  end

  def risk_badge_dot(level)
    color = { "high" => "bg-rose-500", "medium" => "bg-amber-400", "low" => "bg-emerald-400" }[level&.to_s] || "bg-slate-300"
    content_tag(:span, "", class: "inline-block h-2 w-2 rounded-full #{color}")
  end

  def progress_bar_color(enrollment)
    pct = enrollment.progress_pct * 100
    if pct < 30 then "bg-rose-400"
    elsif pct < 70 then "bg-amber-400"
    else "bg-emerald-500"
    end
  end

  def relative_last_active(last_active_at)
    return "Never active" if last_active_at.nil?
    days = ((Time.current - last_active_at) / 1.day).floor
    return "Today"     if days.zero?
    return "Yesterday" if days == 1
    return "#{days} days ago" if days <= 30
    "#{(days / 30.0).floor}mo ago"
  end
end
