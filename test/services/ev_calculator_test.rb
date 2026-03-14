require "test_helper"

class EvCalculatorTest < ActiveSupport::TestCase
  test "calculates EV from payoff probability and effort" do
    move = moves(:atl_pitch)

    assert_in_delta 17.3333, EvCalculator.call(move), 0.0001
  end

  test "returns nil with missing inputs" do
    move = Move.new(title: "No score", payoff_value_normalized: nil, adjusted_probability: 40, effort_minutes: 30)

    assert_nil EvCalculator.call(move)
  end
end
