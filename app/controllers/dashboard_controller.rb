class DashboardController < ApplicationController
  PER_PAGE = 10

  def show
    base = Enrollment.active.includes(:student, :course)

    base = base.where(risk_level: params[:risk]) if %w[high medium low].include?(params[:risk])
    base = base.where(course_id: params[:course_id]) if params[:course_id].present?

    if (@search = params[:q].to_s.strip).present?
      pattern = "%#{@search}%"
      base = base.joins(:student).where("students.full_name LIKE ? OR students.email LIKE ?", pattern, pattern)
    end

    unfiltered = Enrollment.active
    @counts_by_risk = {
      "all"    => unfiltered.count,
      "high"   => unfiltered.where(risk_level: "high").count,
      "medium" => unfiltered.where(risk_level: "medium").count,
      "low"    => unfiltered.where(risk_level: "low").count
    }

    @sort_by = params[:sort_by].presence_in(%w[risk name_asc last_active_asc last_active_desc]) || "risk"
    base = case @sort_by
           when "risk"             then base.by_risk
           when "name_asc"        then base.joins(:student).order("students.full_name ASC")
           when "last_active_asc" then base.by_last_active
           when "last_active_desc" then base.order(Arel.sql("(last_active_at IS NULL), last_active_at DESC"))
           end

    @risk_filter    = params[:risk].presence || "all"
    @course_filter  = params[:course_id].presence
    @filtered_total = base.count
    @page           = [ params[:page].to_i, 1 ].max
    @total_pages    = [ (@filtered_total.to_f / PER_PAGE).ceil, 1 ].max
    @page           = [ @page, @total_pages ].min
    @enrollments    = base.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

    @total_students    = Student.count
    @total_enrollments = Enrollment.active.count
    @at_risk_count     = Enrollment.active.at_risk.count
    @at_risk_pct       = @total_enrollments.zero? ? 0 : (@at_risk_count.to_f / @total_enrollments * 100).round
    @follow_ups_due    = Enrollment.active.where(risk_level: "high").count
    @avg_progress      = begin
      enrollments = Enrollment.active.includes(:course, :activities)
      enrollments.empty? ? 0 : (enrollments.sum(&:progress_pct) / enrollments.size * 100).round
    end
    @courses = Course.order(:name)
  end
end
