require "test_helper"

class ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "archive page loads" do
    get archive_path
    assert_response :success
  end
end
