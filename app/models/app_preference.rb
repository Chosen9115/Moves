class AppPreference < ApplicationRecord
  # The OpenAI API key is a user secret — encrypt it at rest so it never sits in
  # plaintext in the SQLite file or in database dumps/snapshots.
  encrypts :openai_api_key

  validates :ai_provider, inclusion: { in: [ "openai" ] }
  validates :openai_model, presence: true

  def self.current
    first_or_create!(ai_enabled: false, ai_provider: "openai", openai_model: "gpt-4.1-mini")
  end

  def ai_enabled_for_openai?
    ai_provider == "openai" && openai_api_key.present?
  end
end
