require "test_helper"

class FocusControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "focus page loads" do
    get focus_path
    assert_response :success
  end
end
