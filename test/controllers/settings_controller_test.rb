require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "settings loads" do
    get settings_path
    assert_response :success
  end

  test "settings update redirects" do
    patch settings_path, params: {
      app_preference: {
        ai_enabled: "0",
        openai_model: "gpt-4.1-mini"
      }
    }

    assert_redirected_to settings_path
  end
end
