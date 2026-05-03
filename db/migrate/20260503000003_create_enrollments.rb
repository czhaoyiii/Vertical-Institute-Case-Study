class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :student, null: false, foreign_key: true
      t.references :course,  null: false, foreign_key: true
      t.datetime   :enrolled_at,   null: false
      t.string     :status,        null: false, default: "active"
      t.string     :risk_level
      t.datetime   :last_active_at
      t.timestamps
    end

    add_index :enrollments, [ :student_id, :course_id ], unique: true
    add_index :enrollments, :risk_level
    add_index :enrollments, :status
  end
end
