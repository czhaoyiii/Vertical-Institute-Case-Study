class AiSummaryService
  MODEL = "gpt-4o-mini"

  Result = Struct.new(:summary, :immediate_action, :follow_up_subject, :follow_up_message,
                      :reasoning_narrative, :recommended_action, :next_steps,
                      :generated_at, :source, keyword_init: true) do
    def to_db_attrs
      {
        source:              source,
        summary:             summary,
        reasoning_narrative: reasoning_narrative,
        immediate_action:    immediate_action,
        recommended_action:  recommended_action,
        next_steps:          next_steps || [],
        follow_up_subject:   follow_up_subject,
        follow_up_message:   follow_up_message,
        generated_at:        generated_at,
        model:               AiSummaryService::MODEL
      }
    end
  end

  def self.call(enrollment)
    new(enrollment).call
  end

  def self.follow_up(enrollment)
    new(enrollment).follow_up_only
  end

  def initialize(enrollment)
    @enrollment = enrollment
    @assessment = RiskAssessment.call(enrollment)
  end

  def call
    if OpenAIClient.configured?
      begin
        from_openai
      rescue StandardError => e
        Rails.logger.warn "[AiSummaryService] OpenAI call failed (#{e.class}: #{e.message}); falling back to mock."
        fallback
      end
    else
      fallback
    end
  end

  def follow_up_only
    if OpenAIClient.configured?
      begin
        follow_up_from_openai
      rescue StandardError => e
        Rails.logger.warn "[AiSummaryService] Follow-up OpenAI call failed (#{e.class}: #{e.message}); falling back to mock."
        follow_up_fallback
      end
    else
      follow_up_fallback
    end
  end

  private

  def from_openai
    client   = OpenAIClient.build
    response = client.chat(parameters: {
      model:           MODEL,
      response_format: { type: "json_object" },
      temperature:     0.4,
      messages:        [
        { role: "system", content: system_prompt },
        { role: "user",   content: user_prompt }
      ]
    })

    payload = JSON.parse(response.dig("choices", 0, "message", "content").to_s)

    Result.new(
      summary:             payload.fetch("summary"),
      immediate_action:    payload.fetch("immediate_action"),
      follow_up_subject:   payload["follow_up_subject"] || default_subject,
      follow_up_message:   payload.fetch("follow_up_message"),
      reasoning_narrative: payload.fetch("reasoning_narrative"),
      recommended_action:  payload.fetch("recommended_action"),
      next_steps:          Array(payload["next_steps"]).presence || default_next_steps,
      generated_at:        Time.current,
      source:              "openai"
    )
  end

  def follow_up_from_openai
    client   = OpenAIClient.build
    response = client.chat(parameters: {
      model:           MODEL,
      response_format: { type: "json_object" },
      temperature:     0.4,
      messages:        [
        { role: "system", content: follow_up_system_prompt },
        { role: "user",   content: user_prompt }
      ]
    })

    payload = JSON.parse(response.dig("choices", 0, "message", "content").to_s)

    {
      "follow_up_subject" => payload["follow_up_subject"] || default_subject,
      "follow_up_message" => payload.fetch("follow_up_message"),
      "source"            => "openai"
    }
  end

  def fallback
    Result.new(
      summary:             mock_summary,
      immediate_action:    mock_immediate_action,
      follow_up_subject:   default_subject,
      follow_up_message:   mock_follow_up,
      reasoning_narrative: mock_reasoning,
      recommended_action:  mock_recommended_action,
      next_steps:          default_next_steps,
      generated_at:        Time.current,
      source:              "offline"
    )
  end

  def follow_up_fallback
    {
      "follow_up_subject" => default_subject,
      "follow_up_message" => mock_follow_up,
      "source"            => "offline"
    }
  end

  def default_subject
    "Checking in — #{@enrollment.course.name}"
  end

  def default_next_steps
    [
      "Schedule a phone call within 24 hours",
      "Offer a personalised catch-up session",
      "Check if access or tech issues are blocking progress",
      "Review if deadline extensions are appropriate",
      "Discuss workload or payment support options"
    ]
  end

  def system_prompt
    <<~PROMPT
      You are an internal assistant for Vertical Institute, a tech bootcamp. You help
      programme staff act on at-risk students. Tone: warm, concrete, peer-to-peer.

      Return ONLY valid JSON with these exact keys:
        - "summary": 5-7 sentences for staff, plain language, no greetings. Be specific and detailed.
        - "immediate_action": 1 short line (<= 10 words) naming the urgency.
        - "follow_up_subject": a single-line email subject (under 60 chars), no quotes.
        - "follow_up_message": a 4-6 sentence draft email TO the student. Friendly,
          non-judgemental, offers a concrete next step. Sign off with "— Vertical Institute team".
        - "reasoning_narrative": 5-7 sentences explaining WHY the student is at risk and
          which signals matter most, written for staff. Be detailed and specific.
        - "recommended_action": 2-4 sentences with a clear immediate plan.
        - "next_steps": an array of 4-6 short action items.

      Do not invent facts. Use only the structured profile provided.
    PROMPT
  end

  def follow_up_system_prompt
    <<~PROMPT
      You are an internal assistant for Vertical Institute. Draft a follow-up email
      to the student using the structured profile. Tone: warm, concrete, peer-to-peer.

      Return ONLY valid JSON with these exact keys:
        - "follow_up_subject": a single-line email subject (under 60 chars), no quotes.
        - "follow_up_message": a 6-8 sentence draft email TO the student. Friendly,
          non-judgemental, offers a concrete next step. Sign off with "— Vertical Institute team".

      Do not invent facts. Use only the structured profile provided.
    PROMPT
  end

  def user_prompt
    factor_lines = @assessment.factors.map { |f| "- [#{f[:severity]}] #{f[:label]} — #{f[:detail]}" }.join("\n")
    factor_lines = "(none)" if factor_lines.blank?
    attendance   = @enrollment.attendance_rate ? "#{(@enrollment.attendance_rate * 100).round}%" : "unknown"

    <<~PROMPT
      Student profile
      ---------------
      Name: #{@enrollment.student.full_name}
      Course: #{@enrollment.course.name} (#{@enrollment.course.code})
      Risk level: #{@assessment.level}
      Days since last activity: #{format_days(@enrollment.days_since_active)}
      Lessons viewed: #{@enrollment.lessons_viewed_count} of #{@enrollment.course.total_lessons}
      Progress: #{(@enrollment.progress_pct * 100).round}%
      Assignments submitted: #{@enrollment.assignments_submitted_count} of #{@enrollment.course.total_assignments}
      Attendance: #{attendance}

      Risk factors (machine-detected, do not invent others)
      -----------------------------------------------------
      #{factor_lines}

      Recommended next step (already chosen by our system, please reinforce it)
      -------------------------------------------------------------------------
      #{@assessment.recommendation}
    PROMPT
  end

  def format_days(days)
    return "unknown" if days.is_a?(Float) && days.infinite?
    "#{days.to_i} days"
  end

  def mock_summary
    factors = @assessment.factors
    if factors.empty?
      "#{@enrollment.student.full_name} is on track in #{@enrollment.course.name} with no engagement red flags this week."
    else
      "#{@enrollment.student.full_name} (#{@enrollment.course.code}) is showing #{@assessment.level}-risk signals: #{factors.first(2).map { |f| f[:label].to_s.downcase }.to_sentence}. Recommended action: #{@assessment.recommendation.downcase}"
    end
  end

  def mock_follow_up
    student_first  = @enrollment.student.full_name.split.first
    course         = @enrollment.course.name
    primary_factor = @assessment.factors.first
    hook =
      if primary_factor.nil?
        "you're tracking nicely with the cohort"
      else
        case primary_factor[:code].to_s
        when "inactive_long", "inactive_recent"      then "we noticed you haven't logged in in a while"
        when "progress_lag_severe", "progress_lag"   then "we wanted to check in on your pace through the lessons"
        when "consecutive_missed_sessions"            then "we noticed you've missed a couple of recent live sessions"
        when "assignments_missing"                   then "we wanted to check in on your assignment submissions"
        when "attendance_low"                        then "we wanted to flag that your attendance has dipped a bit"
        else "we wanted to check in"
        end
      end

    <<~MSG.chomp
      Hi #{student_first},

      Hope you're doing well — #{hook}. We're really keen to see you finish strong on #{course} and want to make sure nothing's blocking you.

      Could we set up a quick 15-minute chat this week? If now isn't a good time, just reply to this note with a couple of windows that work and we'll find a slot.

      You've got this, and we're here to help.

      — Vertical Institute team
    MSG
  end

  def mock_reasoning
    factors = @assessment.factors
    return "No risk signals are firing for this student. Continue regular monitoring." if factors.empty?

    high    = factors.select { |f| f[:severity].to_s == "high" }
    primary = high.first || factors.first
    others  = factors.reject { |f| f[:code] == primary[:code] }

    base   = "The most weighted signal here is #{primary[:label].to_s.downcase} (#{primary[:detail].to_s.downcase})."
    follow = others.any? ? " On top of that, #{others.first(2).map { |f| f[:label].to_s.downcase }.to_sentence} compound the picture." : ""
    base + follow + " Recommended action: #{@assessment.recommendation.downcase}"
  end

  def mock_immediate_action
    "Immediate outreach needed"
  end

  def mock_recommended_action
    "Immediate outreach is recommended within 24-48 hours. A phone call is preferred to understand blockers and re-engage the student. Offer a short one-on-one session to rebuild momentum and confirm next steps."
  end
end
