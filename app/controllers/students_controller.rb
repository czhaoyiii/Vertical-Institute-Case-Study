class StudentsController < ApplicationController
  def show
    @student = Student.find(params[:id])
    enrollments = @student.enrollments.includes(:course, :activities, :ai_summaries).by_risk
    @primary_enrollment =
      if params[:enrollment_id].present?
        enrollments.find { |e| e.id.to_s == params[:enrollment_id].to_s } || enrollments.first
      else
        enrollments.first
      end
  end
end
