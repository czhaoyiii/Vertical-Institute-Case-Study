class Enrollment < ApplicationRecord
  STATUS      = %w[active completed withdrawn].freeze
  RISK_LEVELS = %w[low medium high].freeze

  belongs_to :student
  belongs_to :course
  has_many :activities,   dependent: :destroy
  has_many :ai_summaries, dependent: :destroy

  validates :student_id, uniqueness: { scope: :course_id }
  validates :status,     inclusion: { in: STATUS }
  validates :risk_level, inclusion: { in: RISK_LEVELS, allow_nil: true }

  scope :active,         -> { where(status: "active") }
  scope :at_risk,        -> { where(risk_level: %w[medium high]) }
  scope :by_last_active, -> { order(Arel.sql("(last_active_at IS NOT NULL), last_active_at ASC")) }
  scope :by_risk,        -> { order(Arel.sql("CASE risk_level WHEN 'high' THEN 0 WHEN 'medium' THEN 1 WHEN 'low' THEN 2 ELSE 3 END, (last_active_at IS NULL), last_active_at ASC")) }

  def lessons_viewed_count
    activities.where(kind: "lesson_viewed").count
  end

  def assignments_submitted_count
    activities.where(kind: "assignment_submitted").count
  end

  def attendance_rate
    total = activities.where(kind: %w[live_session_attended live_session_missed]).count
    return nil if total.zero?
    (activities.where(kind: "live_session_attended").count.to_f / total).round(3)
  end

  def progress_pct
    return 0.0 if course.total_lessons.to_i.zero?
    (lessons_viewed_count.to_f / course.total_lessons).clamp(0.0, 1.0)
  end

  def assignment_completion_rate
    return 1.0 if course.total_assignments.to_i.zero?
    (assignments_submitted_count.to_f / course.total_assignments).clamp(0.0, 1.0)
  end

  def days_since_active(reference_time = Time.current)
    return Float::INFINITY if last_active_at.nil?
    ((reference_time - last_active_at) / 1.day).floor
  end

  def update_last_active!(occurred_at)
    return unless occurred_at
    return if last_active_at && last_active_at >= occurred_at
    update_column(:last_active_at, occurred_at)
  end

  def latest_ai_summary
    ai_summaries.order(generated_at: :desc).first
  end
end
