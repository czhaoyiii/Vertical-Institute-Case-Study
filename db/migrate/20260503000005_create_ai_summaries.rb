class CreateAiSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_summaries do |t|
      t.references :enrollment,         null: false, foreign_key: true
      t.string     :source,             null: false
      t.text       :summary
      t.text       :reasoning_narrative
      t.text       :immediate_action
      t.text       :recommended_action
      t.text       :next_steps
      t.text       :follow_up_subject
      t.text       :follow_up_message
      t.datetime   :generated_at,       null: false
      t.string     :model
      t.string     :prompt_version
      t.timestamps
    end

    add_index :ai_summaries, [ :enrollment_id, :generated_at ]
  end
end
