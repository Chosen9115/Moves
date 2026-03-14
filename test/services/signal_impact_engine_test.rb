require "test_helper"

class SignalImpactEngineTest < ActiveSupport::TestCase
  test "applies positive medium delta" do
    move = moves(:atl_pitch)
    signal = MoveSignal.new(direction: :positive, magnitude: :medium)

    assert_equal 50, SignalImpactEngine.call(move, signal)
  end

  test "clamps probability at boundaries" do
    move = moves(:atl_pitch)
    move.adjusted_probability = 94
    signal = MoveSignal.new(direction: :positive, magnitude: :high)

    assert_equal 95, SignalImpactEngine.call(move, signal)
  end
end
