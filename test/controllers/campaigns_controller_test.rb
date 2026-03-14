require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  test "index loads" do
    get campaigns_path
    assert_response :success
  end

  test "show loads" do
    get campaign_path(campaigns(:quick_pay))
    assert_response :success
  end
end
