require "test_helper"

class FocusControllerTest < ActionDispatch::IntegrationTest
  test "focus page loads" do
    get focus_path
    assert_response :success
  end
end
