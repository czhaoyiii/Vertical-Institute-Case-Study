class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string  :name,              null: false
      t.string  :code,              null: false
      t.integer :total_lessons,     null: false
      t.integer :total_assignments, null: false, default: 0
      t.timestamps
    end

    add_index :courses, :code, unique: true
  end
end
