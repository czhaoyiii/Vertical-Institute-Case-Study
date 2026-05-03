class CoursesController < ApplicationController
  def index
    @courses = Course.order(:name).includes(:enrollments)
  end

  def show
    @course = Course.find(params[:id])
    @enrollments = @course.enrollments.includes(:student).by_risk
    @counts = @course.enrollments.group(:risk_level).count
  end
end
