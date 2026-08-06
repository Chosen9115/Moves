require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "unauthenticated requests to protected pages redirect to sign in" do
    [ root_path, settings_path, moves_path, campaigns_path ].each do |path|
      get path
      assert_redirected_to new_session_path, "expected #{path} to require authentication"
    end
  end

  test "the sign in page itself is reachable without authentication" do
    get new_session_path
    assert_response :success
  end

  test "signing in grants access and signing out revokes it" do
    sign_in_as users(:one)
    get settings_path
    assert_response :success

    sign_out
    get settings_path
    assert_redirected_to new_session_path
  end
end
