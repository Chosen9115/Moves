class AddOpenaiApiKeyToAppPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :app_preferences, :openai_api_key, :string
  end
end
