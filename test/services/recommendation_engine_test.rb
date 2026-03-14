require "test_helper"

class RecommendationEngineTest < ActiveSupport::TestCase
  test "returns push now for high EV active move" do
    move = moves(:atl_pitch)

    assert_equal "Push now", RecommendationEngine.call(move)
  end

  test "returns probably dead for low EV high effort low probability" do
    move = Move.new(
      title: "Weak move",
      payoff_value_normalized: 1,
      adjusted_probability: 10,
      effort_minutes: 480,
      stage: :active
    )

    assert_equal "Probably dead", RecommendationEngine.call(move)
  end
end
