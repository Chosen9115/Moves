require "test_helper"

class QuickCaptureFlowTest < ActionDispatch::IntegrationTest
  test "creates move from title only and redirects to inbox" do
    assert_difference("Campaign.count", 1) do
      assert_difference("Move.count", 1) do
        post moves_path, params: {
          move: {
            title: "Reach out to Monex",
            stage: "inbox",
            campaign_name: "Monex Migration"
          },
          redirect_to: inbox_path
        }
      end
    end

    move = Move.order(:created_at).last
    assert_redirected_to inbox_path
    assert_equal "Reach out to Monex", move.title
    assert_equal "inbox", move.stage
    assert_equal "Monex Migration", move.campaign.name
  end

  test "capture plus clarify redirects to edit screen" do
    post moves_path, params: {
      move: {
        title: "Draft NDA"
      },
      post_capture: "clarify"
    }

    move = Move.order(:created_at).last
    assert_redirected_to edit_move_path(move)
  end
end
