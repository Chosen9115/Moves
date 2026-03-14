class AppPreference < ApplicationRecord
  validates :ai_provider, inclusion: { in: ["openai"] }
  validates :openai_model, presence: true

  def self.current
    first_or_create!(ai_enabled: false, ai_provider: "openai", openai_model: "gpt-4.1-mini")
  end

  def ai_enabled_for_openai?
    ai_provider == "openai" && openai_api_key.present?
  end
end
