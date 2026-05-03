class Course < ApplicationRecord
  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :total_lessons, numericality: { greater_than: 0 }
  validates :total_assignments, numericality: { greater_than_or_equal_to: 0 }
end
