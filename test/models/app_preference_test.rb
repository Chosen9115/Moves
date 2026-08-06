require "test_helper"

class AppPreferenceTest < ActiveSupport::TestCase
  test "openai_api_key round-trips through the model" do
    pref = AppPreference.create!(ai_provider: "openai", openai_model: "gpt-4.1-mini", openai_api_key: "sk-test-secret-123")
    assert_equal "sk-test-secret-123", pref.reload.openai_api_key
  end

  test "openai_api_key is stored encrypted, not as plaintext, at rest" do
    pref = AppPreference.create!(ai_provider: "openai", openai_model: "gpt-4.1-mini", openai_api_key: "sk-test-secret-123")

    raw = AppPreference.connection.select_value(
      "SELECT openai_api_key FROM app_preferences WHERE id = #{pref.id}"
    )
    assert_not_nil raw
    assert_not_equal "sk-test-secret-123", raw, "expected the stored value to be ciphertext"
    assert_not_includes raw, "sk-test-secret-123", "plaintext key leaked into storage"
  end

  test "ai_enabled_for_openai? still reflects key presence" do
    pref = AppPreference.new(ai_provider: "openai", openai_model: "gpt-4.1-mini")
    assert_not pref.ai_enabled_for_openai?

    pref.openai_api_key = "sk-test-secret-123"
    assert pref.ai_enabled_for_openai?
  end
end
