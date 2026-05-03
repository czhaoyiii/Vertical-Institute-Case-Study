class AiSummary < ApplicationRecord
  belongs_to :enrollment

  serialize :next_steps, coder: JSON

  scope :recent_first, -> { order(generated_at: :desc) }
end
