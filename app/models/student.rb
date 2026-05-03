class Student < ApplicationRecord
  has_many :enrollments, dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :activities, through: :enrollments

  validates :full_name, presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  def initials
    full_name.split.first(2).map { |n| n[0] }.join.upcase
  end
end
