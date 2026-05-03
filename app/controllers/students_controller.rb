class StudentsController < ApplicationController
  def show
    @student = Student.find(params[:id])
    enrollments = @student.enrollments.includes(:course, :activities, :ai_summaries).by_risk
    @primary_enrollment = enrollments.first
  end
end
