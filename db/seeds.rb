require "faker"

puts "[seeds] clearing existing data..."
AiSummary.delete_all
Activity.delete_all
Enrollment.delete_all
Student.delete_all
Course.delete_all

now = Time.current

puts "[seeds] creating courses..."
courses = [
  { name: "Data Analytics Bootcamp",    code: "DAB-26", total_lessons: 40, total_assignments: 8  },
  { name: "Generative AI Fundamentals", code: "GAI-26", total_lessons: 24, total_assignments: 6  },
  { name: "Full-Stack Web Development", code: "FSW-26", total_lessons: 60, total_assignments: 10 }
].map { |attrs| Course.create!(attrs) }

ARCHETYPES = [
  { key: :on_track,        weight: 9 },
  { key: :slightly_behind, weight: 7 },
  { key: :lagging,         weight: 9 },
  { key: :disengaging,     weight: 4 },
  { key: :silent,          weight: 1 }
].freeze

ARCHETYPE_POOL = ARCHETYPES.flat_map { |a| Array.new(a[:weight], a[:key]) }.freeze

def archetype_attrs(archetype, course)
  total       = course.total_lessons
  assignments = course.total_assignments

  case archetype
  when :on_track
    { lesson_count: (total * 0.75).round, assignment_count: [ assignments, rand(7..8) ].min,
      weeks_elapsed: 6, attend_rate: rand(0.90..0.99), last_active_offset: rand(0..1).days }
  when :slightly_behind
    { lesson_count: (total * 0.50).round, assignment_count: [ assignments, rand(5..7) ].min,
      weeks_elapsed: 6, attend_rate: rand(0.78..0.88), last_active_offset: rand(3..5).days }
  when :lagging
    { lesson_count: (total * 0.35).round, assignment_count: [ assignments, rand(4..6) ].min,
      weeks_elapsed: 6, attend_rate: rand(0.75..0.85), last_active_offset: rand(8..12).days }
  when :disengaging
    { lesson_count: (total * 0.20).round, assignment_count: [ assignments, rand(1..3) ].min,
      weeks_elapsed: 6, attend_rate: rand(0.40..0.60), last_active_offset: rand(15..22).days }
  when :silent
    { lesson_count: 0, assignment_count: 0,
      weeks_elapsed: 6, attend_rate: rand(0.10..0.30), last_active_offset: rand(25..35).days }
  end
end

def generate_activities(enrollment, attrs, now, engagement_cutoff:)
  start_time    = enrollment.enrolled_at
  lesson_count  = attrs[:lesson_count]
  assign_count  = attrs[:assignment_count]
  weeks_elapsed = attrs[:weeks_elapsed]
  attend_rate   = attrs[:attend_rate]
  span          = engagement_cutoff - start_time

  if lesson_count.positive? && span.positive?
    lesson_count.times do |i|
      Activity.create!(
        enrollment:  enrollment,
        kind:        "lesson_viewed",
        occurred_at: start_time + span * ((i + 1).to_f / (lesson_count + 1)),
        metadata:    { lesson_index: i + 1 }
      )
    end
  end

  if assign_count.positive? && span.positive?
    assign_count.times do |i|
      Activity.create!(
        enrollment:  enrollment,
        kind:        "assignment_submitted",
        occurred_at: start_time + span * ((i + 1).to_f / (assign_count + 1)),
        metadata:    { assignment_index: i + 1 }
      )
    end
  end

  attended_count = (weeks_elapsed * attend_rate).round
  missed_count   = weeks_elapsed - attended_count

  weeks_elapsed.times do |week_index|
    occurred_at = start_time + (week_index * 1.week) + 3.days
    next if occurred_at > now

    after_cutoff = occurred_at > engagement_cutoff
    kind = if after_cutoff
      "live_session_missed"
    elsif missed_count.positive? && rand < (missed_count.to_f / [ weeks_elapsed, 1 ].max)
      missed_count -= 1
      "live_session_missed"
    else
      "live_session_attended"
    end

    Activity.create!(
      enrollment:  enrollment,
      kind:        kind,
      occurred_at: occurred_at,
      metadata:    { week: week_index + 1 }
    )
  end
end

TITLE_PATTERN  = /\A(Mr\.?|Mrs\.?|Ms\.?|Miss|Dr\.?|Prof\.?|Sir|Sen\.?|Rev\.?|Fr\.?|Hon\.?)\s+/i.freeze
SUFFIX_PATTERN = /\s+(Jr\.?|Sr\.?|II|III|IV|V|VI|PhD|MD|DVM|DDS|JD|Esq\.?|Ret\.?|VM|MBA|CPA|RN|EdD)\z/i.freeze

def clean_name(raw)
  raw.sub(TITLE_PATTERN, "").sub(SUFFIX_PATTERN, "").strip
end

puts "[seeds] creating students and enrollments..."
enrolled_at_base = now - 6.weeks

30.times do |i|
  student = Student.create!(
    full_name: clean_name(Faker::Name.name),
    email:     "student#{i + 1}+#{SecureRandom.hex(2)}@example.com"
  )

  course_count    = rand < 0.3 ? 2 : 1
  student_courses = courses.sample(course_count)

  student_courses.each do |course|
    archetype   = ARCHETYPE_POOL.sample
    attrs       = archetype_attrs(archetype, course)
    enrolled_at = enrolled_at_base + rand(0..3).days

    enrollment = Enrollment.create!(
      student:     student,
      course:      course,
      enrolled_at: enrolled_at,
      status:      "active"
    )

    cutoff = now - attrs[:last_active_offset]
    generate_activities(enrollment, attrs, now, engagement_cutoff: cutoff)

    if archetype == :silent
      enrollment.update_column(:last_active_at, nil)
    else
      enrollment.update_column(:last_active_at, cutoff)
    end
  end
end

puts "[seeds] computing risk for every enrollment..."
Enrollment.includes(:course, :activities).find_each do |enrollment|
  RiskAssessment.call(enrollment).persist!
end

puts "[seeds] done."
puts "  courses:     #{Course.count}"
puts "  students:    #{Student.count}"
puts "  enrollments: #{Enrollment.count} (#{Enrollment.group(:status).count})"
puts "  activities:  #{Activity.count}"
