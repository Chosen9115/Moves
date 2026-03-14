require "test_helper"

class FocusClassifierTest < ActiveSupport::TestCase
  test "groups moves into focus buckets" do
    buckets = FocusClassifier.call(Move.all)

    assert_includes buckets[:best_moves_now], moves(:atl_pitch)
    assert_includes buckets[:strategic_bets], moves(:atl_pitch)
    assert buckets[:needs_a_call].is_a?(Array)
  end
end
