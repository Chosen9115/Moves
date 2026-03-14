require "test_helper"

class InboxControllerTest < ActionDispatch::IntegrationTest
  test "inbox page loads" do
    get inbox_path
    assert_response :success
  end
end
