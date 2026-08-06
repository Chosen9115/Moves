require "test_helper"

class Api::V1::MovesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @read_token_record, @read_token_raw = ApiToken.generate!(
      name: "test_read", scopes: "moves:read"
    )
    @write_token_record, @write_token_raw = ApiToken.generate!(
      name: "test_write", scopes: "moves:read moves:write"
    )
    @read_only_record, @read_only_raw = ApiToken.generate!(
      name: "test_ro_only", scopes: "moves:read"
    )
  end

  # -------------------------------------------------------------------------
  # 401 — no token
  # -------------------------------------------------------------------------
  test "401 when no token provided" do
    get "/api/v1/moves", as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", json_body.dig("error", "code")
  end

  test "401 when malformed authorization header" do
    get "/api/v1/moves",
        headers: { "Authorization" => "NotBearer xyz" },
        as: :json
    assert_response :unauthorized
  end

  # -------------------------------------------------------------------------
  # 401 — revoked token
  # -------------------------------------------------------------------------
  test "401 when token is revoked" do
    @read_token_record.revoke!
    get "/api/v1/moves", headers: bearer(@read_token_raw), as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", json_body.dig("error", "code")
  end

  # -------------------------------------------------------------------------
  # 403 — valid token but wrong scope
  # -------------------------------------------------------------------------
  test "403 when read token tries to create a move" do
    post "/api/v1/moves",
         params: { move: { title: "No-scope move" } },
         headers: bearer(@read_token_raw),
         as: :json
    assert_response :forbidden
    assert_equal "forbidden", json_body.dig("error", "code")
  end

  test "403 when read-only token tries to update a move" do
    move = moves(:atl_pitch)
    patch "/api/v1/moves/#{move.id}",
          params: { move: { title: "Updated" } },
          headers: bearer(@read_only_raw),
          as: :json
    assert_response :forbidden
  end

  # -------------------------------------------------------------------------
  # 200 — index
  # -------------------------------------------------------------------------
  test "200 index returns moves array with meta" do
    get "/api/v1/moves", headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    body = json_body
    assert body.key?("moves")
    assert body.key?("meta")
    assert_includes body["meta"].keys, "page"
    assert_includes body["meta"].keys, "per"
    assert_includes body["meta"].keys, "total"
  end

  test "index paginates correctly" do
    get "/api/v1/moves?page=1&per=1", headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    assert_equal 1, json_body["moves"].length
    assert_equal 1, json_body["meta"]["per"]
  end

  test "index caps per at 100" do
    get "/api/v1/moves?per=9999", headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    assert_equal 100, json_body["meta"]["per"]
  end

  # -------------------------------------------------------------------------
  # 200 — show
  # -------------------------------------------------------------------------
  test "200 show returns move detail" do
    move = moves(:atl_pitch)
    get "/api/v1/moves/#{move.id}", headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    body = json_body
    assert_equal move.id,    body["id"]
    assert_equal move.uuid,  body["uuid"]
    assert_equal move.title, body["title"]
  end

  # -------------------------------------------------------------------------
  # 404 — not found
  # -------------------------------------------------------------------------
  test "404 when move does not exist" do
    get "/api/v1/moves/999999", headers: bearer(@read_token_raw), as: :json
    assert_response :not_found
    assert_equal "not_found", json_body.dig("error", "code")
  end

  # -------------------------------------------------------------------------
  # 201 — create
  # -------------------------------------------------------------------------
  test "201 create with valid params" do
    assert_difference "Move.count", 1 do
      post "/api/v1/moves",
           params: { move: { title: "New API Move" } },
           headers: bearer(@write_token_raw),
           as: :json
    end
    assert_response :created
    body = json_body
    assert_equal "New API Move", body["title"]
    assert body["id"].present?
  end

  test "201 create with optional fields" do
    post "/api/v1/moves",
         params: {
           move: {
             title: "Detailed Move",
             effort_minutes: 30,
             subjective_probability: 60,
             payoff_value_normalized: 5
           }
         },
         headers: bearer(@write_token_raw),
         as: :json
    assert_response :created
    body = json_body
    assert_equal 30, body["effort_minutes"]
    assert_equal 60, body["subjective_probability"]
    assert_equal 5,  body["payoff_value_normalized"]
  end

  # -------------------------------------------------------------------------
  # 422 — invalid create
  # -------------------------------------------------------------------------
  test "422 create without required title" do
    post "/api/v1/moves",
         params: { move: { description: "Missing title" } },
         headers: bearer(@write_token_raw),
         as: :json
    assert_response :unprocessable_entity
    body = json_body
    assert_equal "validation_failed", body.dig("error", "code")
    assert body.dig("error", "details").any? { |e| e.match?(/title/i) }
  end

  test "422 create with invalid effort_minutes" do
    post "/api/v1/moves",
         params: { move: { title: "Bad effort", effort_minutes: 999 } },
         headers: bearer(@write_token_raw),
         as: :json
    assert_response :unprocessable_entity
  end

  test "422 (not 500) create with out-of-range enum value" do
    post "/api/v1/moves",
         params: { move: { title: "Bad enum", move_type: "not_a_type" } },
         headers: bearer(@write_token_raw),
         as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_argument", json_body.dig("error", "code")
  end

  test "stage cannot be set via the API — new moves stay in inbox" do
    post "/api/v1/moves",
         params: { move: { title: "Sneaky complete", stage: "completed" } },
         headers: bearer(@write_token_raw),
         as: :json
    assert_response :created
    assert_equal "inbox", json_body["stage"]
    assert_nil Move.find(json_body["id"]).completed_at
  end

  # -------------------------------------------------------------------------
  # update
  # -------------------------------------------------------------------------
  test "200 update with valid params" do
    move = moves(:atl_pitch)
    patch "/api/v1/moves/#{move.id}",
          params: { move: { title: "Updated Title" } },
          headers: bearer(@write_token_raw),
          as: :json
    assert_response :ok
    assert_equal "Updated Title", json_body["title"]
  end

  test "stage cannot be set via the API on update" do
    move = moves(:atl_pitch)
    original_stage = move.stage
    patch "/api/v1/moves/#{move.id}",
          params: { move: { title: "Renamed", stage: "completed" } },
          headers: bearer(@write_token_raw),
          as: :json
    assert_response :ok
    assert_equal "Renamed", json_body["title"]
    assert_equal original_stage, move.reload.stage
    assert_nil move.completed_at
  end

  test "404 update for non-existent move" do
    patch "/api/v1/moves/999999",
          params: { move: { title: "Ghost" } },
          headers: bearer(@write_token_raw),
          as: :json
    assert_response :not_found
  end

  private

  def bearer(raw_token)
    { "Authorization" => "Bearer #{raw_token}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end
