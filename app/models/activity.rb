class Activity < ApplicationRecord
  KINDS = %w[login lesson_viewed assignment_submitted live_session_attended live_session_missed quiz_attempted].freeze

  belongs_to :enrollment

  serialize :metadata, coder: JSON

  validates :kind,        inclusion: { in: KINDS }
  validates :occurred_at, presence: true

  after_create_commit :sync_last_active

  private

  def sync_last_active
    return if kind == "live_session_missed"
    enrollment.update_last_active!(occurred_at)
  end
end
