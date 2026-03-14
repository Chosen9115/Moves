require "test_helper"

class BackupsControllerTest < ActionDispatch::IntegrationTest
  test "export endpoint responds" do
    get export_backups_path
    assert_response :success
  end

  test "import without file redirects" do
    post import_backups_path
    assert_redirected_to settings_path
  end
end
