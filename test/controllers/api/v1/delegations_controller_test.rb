require "test_helper"

class Api::V1::DelegationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @orchestrator_record, @orchestrator_raw = ApiToken.generate!(
      name: "carlos", scopes: "moves:read moves:write"
    )
    @darwin_record, @darwin_raw = ApiToken.generate!(
      name: "darwin", scopes: "delegation:read delegation:write"
    )
    @olympus_record, @olympus_raw = ApiToken.generate!(
      name: "olympus", scopes: "delegation:read delegation:write"
    )
    @move = moves(:atl_pitch)
  end

  # ── Scope 403 ─────────────────────────────────────────────────────────────

  test "403 when token lacks delegation:read scope" do
    get "/api/v1/delegations", headers: bearer(@orchestrator_raw), as: :json
    assert_response :forbidden
    assert_equal "forbidden", json_body.dig("error", "code")
  end

  test "401 without token" do
    get "/api/v1/delegations", as: :json
    assert_response :unauthorized
  end

  # ── Queue isolation ────────────────────────────────────────────────────────

  test "agent only sees its own delegated moves" do
    # Delegate to darwin
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok

    # darwin polls — should see the move
    get "/api/v1/delegations", headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    ids = json_body["moves"].map { |m| m["id"] }
    assert_includes ids, @move.id
  end

  test "olympus cannot see darwin's delegated moves" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok

    # olympus polls — must NOT see darwin's move
    get "/api/v1/delegations", headers: bearer(@olympus_raw), as: :json
    assert_response :ok
    ids = json_body["moves"].map { |m| m["id"] }
    assert_not_includes ids, @move.id
  end

  test "can filter by delegation state" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok

    # Filter by delegated — should return the move
    get "/api/v1/delegations?state=delegated", headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    assert json_body["moves"].any? { |m| m["id"] == @move.id }

    # Filter by accepted — not there yet
    get "/api/v1/delegations?state=accepted", headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    assert_equal [], json_body["moves"]
  end

  test "422 on invalid state param" do
    get "/api/v1/delegations?state=bogus", headers: bearer(@darwin_raw), as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_argument", json_body.dig("error", "code")
  end

  test "response includes delegation fields" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json

    get "/api/v1/delegations", headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    move_json = json_body["moves"].find { |m| m["id"] == @move.id }
    assert move_json
    assert_equal "darwin", move_json.dig("delegation", "assignee")
    assert_equal "delegated", move_json.dig("delegation", "delegation_state")
    assert move_json["delegation_id"].present?
  end

  private

  def bearer(raw_token)
    { "Authorization" => "Bearer #{raw_token}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end
