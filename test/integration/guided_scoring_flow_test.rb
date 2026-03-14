require "test_helper"

class GuidedScoringFlowTest < ActionDispatch::IntegrationTest
  test "updates move with scoring inputs and recommendation" do
    move = moves(:cabalo_followup)

    patch move_path(move), params: {
      move: {
        success_definition: "Meeting booked",
        payoff_value_normalized: 8,
        payoff_tags_string: "relationship, leverage, acquisition",
        subjective_probability: 40,
        adjusted_probability: 40,
        effort_minutes: 30,
        advantages_string: "warm intro",
        blockers_string: "timing"
      }
    }

    assert_redirected_to move_path(move)
    move.reload
    assert_not_nil move.ev_score
    assert_not_nil move.recommendation
    assert move.active?
    assert_equal %w[relationship leverage acquisition], move.payoff_tags
  end
end
