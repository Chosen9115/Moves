require "test_helper"

class MoveTest < ActiveSupport::TestCase
  test "applies strategic defaults after success definition" do
    move = Move.new(
      title: "Strategic move",
      move_type: :strategic,
      success_definition: "Pilot approved"
    )

    move.valid?

    assert_equal 8, move.payoff_value_normalized
    assert_equal 25, move.adjusted_probability
    assert_equal 120, move.effort_minutes
  end

  test "supports only known payoff tags" do
    move = Move.new(
      title: "Tag test",
      payoff_tags: [ "relationship", "unknown_tag" ]
    )

    assert_not move.valid?
    assert_includes move.errors[:payoff_tags].first, "unsupported"
  end
end
