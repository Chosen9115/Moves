require "test_helper"

class SignalLoggingFlowTest < ActionDispatch::IntegrationTest
  test "logs signal and adjusts probability" do
    move = moves(:atl_pitch)
    original_probability = move.adjusted_probability

    assert_difference("MoveSignal.count", 1) do
      post move_signals_path(move), params: {
        move_signal: {
          signal_type: "Positive reply",
          direction: "positive",
          magnitude: "medium",
          note: "Great momentum"
        }
      }
    end

    assert_redirected_to move_path(move)
    move.reload
    assert_equal original_probability + 10, move.adjusted_probability
  end
end
