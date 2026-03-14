require "test_helper"

class CampaignGroupingFlowTest < ActionDispatch::IntegrationTest
  test "campaign show renders grouped moves" do
    campaign = campaigns(:quick_pay)

    get campaign_path(campaign)

    assert_response :success
    assert_match campaign.name, @response.body
    assert_match moves(:atl_pitch).title, @response.body
  end
end
