class RiskAssessment
  Result = Struct.new(:level, :score, :factors, :recommendation, :enrollment, keyword_init: true) do
    def persist!
      enrollment.update_column(:risk_level, level.to_s)
      self
    end

    def at_risk?
      level != :low
    end
  end

  Factor = Struct.new(:code, :label, :severity, :detail, :points, keyword_init: true) do
    def to_h
      { code: code, label: label, severity: severity.to_s, detail: detail, points: points }
    end
  end

  THRESHOLDS = {
    inactive_recent_days:        7,
    inactive_long_days:          14,
    progress_floor_pct:          0.30,
    progress_floor_severe_pct:   0.10,
    assignment_completion_floor: 0.6,
    attendance_floor:            0.7,
    consecutive_missed_window:   3,
    consecutive_missed_min:      2
  }.freeze

  RECOMMENDATIONS = {
    inactive_long:               "Personal outreach call within 24 hours to re-engage the student.",
    progress_lag_severe:         "Schedule a 1:1 catch-up session and adjust upcoming deadlines.",
    consecutive_missed_sessions: "Check in about scheduling conflicts and offer makeup sessions.",
    inactive_recent:             "Send a friendly nudge today and confirm no blockers.",
    progress_lag:                "Share a short pace-recovery plan over email.",
    assignments_missing:         "Remind the student of pending assignments with extended deadlines.",
    attendance_low:              "Confirm the student's schedule fits and discuss flexible attendance options.",
    none:                        "Monitor — no action required this week."
  }.freeze

  RECOMMENDATION_PRIORITY = %i[
    inactive_long
    progress_lag_severe
    consecutive_missed_sessions
    inactive_recent
    progress_lag
    assignments_missing
    attendance_low
  ].freeze

  def self.call(enrollment, reference_time: Time.current)
    new(enrollment, reference_time: reference_time).call
  end

  def initialize(enrollment, reference_time: Time.current)
    @enrollment     = enrollment
    @reference_time = reference_time
  end

  def call
    factors = collect_factors
    score   = factors.sum(&:points)
    level   = band_for(score)
    Result.new(
      level:          level,
      score:          score,
      factors:        factors.map(&:to_h),
      recommendation: pick_recommendation(factors),
      enrollment:     @enrollment
    )
  end

  private

  def collect_factors
    [
      inactivity_factor,
      progress_factor,
      assignments_factor,
      attendance_factor,
      missed_sessions_factor
    ].compact
  end

  def inactivity_factor
    days = @enrollment.days_since_active(@reference_time)
    return nil if days < THRESHOLDS[:inactive_recent_days]

    if days >= THRESHOLDS[:inactive_long_days]
      Factor.new(code: :inactive_long, label: "Inactive for #{days_label(days)}", severity: :high,
                 detail: "Last login or activity was #{days_label(days)} ago.", points: 40)
    else
      Factor.new(code: :inactive_recent, label: "Inactive for #{days_label(days)}", severity: :medium,
                 detail: "Last login or activity was #{days_label(days)} ago.", points: 25)
    end
  end

  def progress_factor
    pct = @enrollment.progress_pct
    return nil if pct >= THRESHOLDS[:progress_floor_pct]

    if pct < THRESHOLDS[:progress_floor_severe_pct]
      Factor.new(code: :progress_lag_severe, label: "Severely behind expected pace", severity: :high,
                 detail: "Only #{(pct * 100).round}% of lessons viewed — well below expected completion.",
                 points: 40)
    else
      Factor.new(code: :progress_lag, label: "Behind expected pace", severity: :medium,
                 detail: "#{(pct * 100).round}% of lessons viewed — below 30% completion threshold.",
                 points: 25)
    end
  end

  def assignments_factor
    return nil if @enrollment.course.total_assignments.to_i.zero?
    rate = @enrollment.assignment_completion_rate
    return nil if rate >= THRESHOLDS[:assignment_completion_floor]

    submitted = @enrollment.assignments_submitted_count
    total     = @enrollment.course.total_assignments
    Factor.new(code: :assignments_missing, label: "Missing assignments", severity: :medium,
               detail: "Submitted #{submitted} of #{total} assignments (#{(rate * 100).round}%).",
               points: 15)
  end

  def attendance_factor
    rate = @enrollment.attendance_rate
    return nil if rate.nil? || rate >= THRESHOLDS[:attendance_floor]

    Factor.new(code: :attendance_low, label: "Low attendance", severity: :medium,
               detail: "Live session attendance is #{(rate * 100).round}%.", points: 15)
  end

  def missed_sessions_factor
    recent = @enrollment.activities
      .where(kind: %w[live_session_attended live_session_missed])
      .order(occurred_at: :desc)
      .limit(THRESHOLDS[:consecutive_missed_window])

    missed_count = recent.count { |a| a.kind == "live_session_missed" }
    return nil if missed_count < THRESHOLDS[:consecutive_missed_min]

    Factor.new(code: :consecutive_missed_sessions, label: "Missed multiple live sessions", severity: :high,
               detail: "#{missed_count} of last #{recent.size} live sessions were missed.", points: 20)
  end

  def band_for(score)
    return :high   if score >= 60
    return :medium if score >= 30
    :low
  end

  def pick_recommendation(factors)
    codes  = factors.map(&:code)
    chosen = RECOMMENDATION_PRIORITY.find { |c| codes.include?(c) }
    RECOMMENDATIONS[chosen || :none]
  end

  def days_label(days)
    return "more than 30 days" if days > 30
    days == 1 ? "1 day" : "#{days} days"
  end
end
