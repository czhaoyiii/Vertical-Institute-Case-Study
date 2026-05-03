class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.references :enrollment, null: false, foreign_key: true
      t.string     :kind,        null: false
      t.datetime   :occurred_at, null: false
      t.text       :metadata
      t.datetime   :created_at,  null: false
    end

    add_index :activities, [ :enrollment_id, :occurred_at ]
    add_index :activities, :kind
  end
end
