require "test_helper"

class InboxControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "inbox page loads" do
    get inbox_path
    assert_response :success
  end
end
