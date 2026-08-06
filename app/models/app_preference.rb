class AppPreference < ApplicationRecord
  # The OpenAI API key is a user secret — encrypt it at rest so it never sits in
  # plaintext in the SQLite file or in database dumps/snapshots.
  encrypts :openai_api_key

  validates :ai_provider, inclusion: { in: [ "openai" ] }
  validates :openai_model, presence: true

  def self.current
    first_or_create!(ai_enabled: false, ai_provider: "openai", openai_model: "gpt-4.1-mini")
  end

  # One-time rollout helper: re-encrypt any openai_api_key still stored as
  # plaintext (from before `encrypts` was added). Idempotent — rows already
  # holding an encrypted payload are skipped. Returns the number re-encrypted.
  def self.encrypt_legacy_plaintext!
    count = 0
    find_each do |pref|
      raw = connection.select_value(
        sanitize_sql([ "SELECT openai_api_key FROM app_preferences WHERE id = ?", pref.id ])
      )
      next if raw.blank? || encrypted_payload?(raw)

      pref.openai_api_key_will_change!
      pref.save!(validate: false)
      count += 1
    end
    count
  end

  # Active Record non-deterministic encryption stores a JSON envelope like
  # {"p":"…","h":{…}}; a raw value that isn't such an envelope is plaintext.
  def self.encrypted_payload?(raw)
    parsed = JSON.parse(raw)
    parsed.is_a?(Hash) && parsed.key?("p")
  rescue JSON::ParserError
    false
  end

  def ai_enabled_for_openai?
    ai_provider == "openai" && openai_api_key.present?
  end
end
