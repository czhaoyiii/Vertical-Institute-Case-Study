# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_03_000005) do
  create_table "students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_students_on_email", unique: true
  end

  create_table "courses", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "total_assignments", default: 0, null: false
    t.integer "total_lessons", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_courses_on_code", unique: true
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.datetime "enrolled_at", null: false
    t.datetime "last_active_at"
    t.string "risk_level"
    t.string "status", default: "active", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["risk_level"], name: "index_enrollments_on_risk_level"
    t.index ["status"], name: "index_enrollments_on_status"
    t.index ["student_id", "course_id"], name: "index_enrollments_on_student_id_and_course_id", unique: true
    t.index ["student_id"], name: "index_enrollments_on_student_id"
  end

  create_table "activities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "enrollment_id", null: false
    t.string "kind", null: false
    t.text "metadata"
    t.datetime "occurred_at", null: false
    t.index ["enrollment_id", "occurred_at"], name: "index_activities_on_enrollment_id_and_occurred_at"
    t.index ["enrollment_id"], name: "index_activities_on_enrollment_id"
    t.index ["kind"], name: "index_activities_on_kind"
  end

  create_table "ai_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "enrollment_id", null: false
    t.text "follow_up_message"
    t.text "follow_up_subject"
    t.datetime "generated_at", null: false
    t.text "immediate_action"
    t.string "model"
    t.text "next_steps"
    t.string "prompt_version"
    t.text "reasoning_narrative"
    t.text "recommended_action"
    t.string "source", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "generated_at"], name: "index_ai_summaries_on_enrollment_id_and_generated_at"
    t.index ["enrollment_id"], name: "index_ai_summaries_on_enrollment_id"
  end

  add_foreign_key "activities", "enrollments"
  add_foreign_key "ai_summaries", "enrollments"
  add_foreign_key "enrollments", "courses"
  add_foreign_key "enrollments", "students"
end
