require "test_helper"

class ArchivesControllerTest < ActionDispatch::IntegrationTest
  test "archive page loads" do
    get archive_path
    assert_response :success
  end
end
