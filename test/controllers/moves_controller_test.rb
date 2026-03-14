require "test_helper"

class MovesControllerTest < ActionDispatch::IntegrationTest
  test "moves index loads" do
    get moves_path
    assert_response :success
  end

  test "move show loads" do
    get move_path(moves(:atl_pitch))
    assert_response :success
  end
end
