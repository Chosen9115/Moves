require "test_helper"

class Api::V1::TodayControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token_record, @token_raw = ApiToken.generate!(
      name: "today_test", scopes: "moves:read"
    )
  end

  test "401 when no token provided" do
    get "/api/v1/today", as: :json
    assert_response :unauthorized
  end

  test "200 today returns moves array" do
    get "/api/v1/today", headers: bearer(@token_raw), as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("moves")
    assert body["moves"].is_a?(Array)
  end

  test "today includes moves due today" do
    due_move = Move.create!(title: "Due today move", due_date: Date.current)
    get "/api/v1/today", headers: bearer(@token_raw), as: :json
    assert_response :ok
    ids = JSON.parse(response.body)["moves"].map { |m| m["id"] }
    assert_includes ids, due_move.id
  end

  test "today deduplicates moves" do
    # Create a move that has due_date today AND would appear in best_moves_now
    move = Move.create!(
      title: "High EV due today",
      due_date: Date.current,
      stage: :active,
      success_definition: "Done",
      payoff_value_normalized: 13,
      adjusted_probability: 75,
      effort_minutes: 30,
      recommendation: "Push now"
    )
    get "/api/v1/today", headers: bearer(@token_raw), as: :json
    assert_response :ok
    ids = JSON.parse(response.body)["moves"].map { |m| m["id"] }
    assert_equal ids.uniq, ids, "Duplicate moves found in /today response"
    assert_includes ids, move.id
  end

  private

  def bearer(raw_token)
    { "Authorization" => "Bearer #{raw_token}" }
  end
end
