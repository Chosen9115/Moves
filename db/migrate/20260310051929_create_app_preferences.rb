class CreateAppPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :app_preferences do |t|
      t.boolean :ai_enabled, null: false, default: false
      t.string :ai_provider, null: false, default: "openai"
      t.string :openai_model, null: false, default: "gpt-4.1-mini"

      t.timestamps
    end
  end
end
