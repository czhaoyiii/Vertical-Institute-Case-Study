module Students
  class AiSummariesController < ApplicationController
    include ActionView::RecordIdentifier

    before_action :set_enrollment

    def show
      unless @enrollment.latest_ai_summary
        result = AiSummaryService.call(@enrollment)
        @enrollment.ai_summaries.create!(result.to_db_attrs)
      end
      respond_to do |format|
        format.html do
          redirect_to student_path(@enrollment.student) unless turbo_frame_request?
          render :show
        end
      end
    end

    def create
      result = AiSummaryService.call(@enrollment)
      @ai_summary = @enrollment.ai_summaries.create!(result.to_db_attrs)
      @notice = result.source == "offline" ? "OpenAI key not configured — showing offline output." : nil
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to student_path(@enrollment.student) }
      end
    end

    def follow_up
      data = AiSummaryService.follow_up(@enrollment)
      ai   = @enrollment.latest_ai_summary

      if ai
        ai.update!(
          follow_up_subject: data["follow_up_subject"],
          follow_up_message: data["follow_up_message"],
          source:            data["source"]
        )
      else
        @enrollment.ai_summaries.create!(
          source:            data["source"],
          follow_up_subject: data["follow_up_subject"],
          follow_up_message: data["follow_up_message"],
          generated_at:      Time.current
        )
      end

      @enrollment.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to student_path(@enrollment.student) }
      end
    end

    private

    def set_enrollment
      @student      = Student.find(params[:student_id])
      enrollment_id = params[:enrollment_id] || @student.enrollments.by_risk.pick(:id)
      @enrollment   = @student.enrollments.find(enrollment_id)
    end
  end
end
