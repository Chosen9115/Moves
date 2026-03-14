require "test_helper"

class SignalsControllerTest < ActionDispatch::IntegrationTest
  test "create signal redirects to move" do
    move = moves(:atl_pitch)

    post move_signals_path(move), params: {
      move_signal: {
        signal_type: "Follow-up response",
        direction: "positive",
        magnitude: "low"
      }
    }

    assert_redirected_to move_path(move)
  end
end
