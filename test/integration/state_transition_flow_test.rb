require "test_helper"

class StateTransitionFlowTest < ActionDispatch::IntegrationTest
  test "pause archive complete and reactivate flows" do
    move = moves(:atl_pitch)

    patch pause_move_path(move)
    assert_redirected_to move_path(move)
    assert_equal "paused", move.reload.stage

    patch archive_move_path(move)
    assert_equal "archived", move.reload.stage

    patch activate_move_path(move)
    assert_equal "active", move.reload.stage

    patch complete_move_path(move)
    assert_equal "completed", move.reload.stage
    assert_not_nil move.reload.completed_at
  end
end
