require "test_helper"

class Api::V1::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @read_token_record, @read_token_raw = ApiToken.generate!(
      name: "notes_read",  scopes: "notes:read"
    )
    @write_token_record, @write_token_raw = ApiToken.generate!(
      name: "notes_write", scopes: "notes:read notes:write"
    )
    @wrong_scope_record, @wrong_scope_raw = ApiToken.generate!(
      name: "moves_only",  scopes: "moves:read moves:write"
    )
    @move = moves(:atl_pitch)
    @note = notes(:atl_note_one)

    # Ensure METIS_CLI is unset so no real Metis calls happen
    ENV.delete("METIS_CLI")
  end

  # ── Scope 403s ────────────────────────────────────────────────────────

  test "403 on index without notes:read scope" do
    get "/api/v1/moves/#{@move.id}/notes",
        headers: bearer(@wrong_scope_raw), as: :json
    assert_response :forbidden
    assert_equal "forbidden", json_body.dig("error", "code")
  end

  test "403 on create without notes:write scope" do
    post "/api/v1/moves/#{@move.id}/notes",
         params: { note: { body: "hi" } },
         headers: bearer(@read_token_raw), as: :json
    assert_response :forbidden
  end

  test "403 on search without notes:read scope" do
    get "/api/v1/notes/search?q=test",
        headers: bearer(@wrong_scope_raw), as: :json
    assert_response :forbidden
  end

  # ── INDEX ─────────────────────────────────────────────────────────────

  test "200 index returns notes array for the move" do
    get "/api/v1/moves/#{@move.id}/notes",
        headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    body = json_body
    assert body.key?("notes"), "Response should have a notes key"
    uuids = body["notes"].map { |n| n["uuid"] }
    assert_includes uuids, notes(:atl_note_one).uuid
    assert_includes uuids, notes(:atl_prompt_one).uuid
    assert_not_includes uuids, notes(:cabalo_note_one).uuid
  end

  test "404 index when move does not exist" do
    get "/api/v1/moves/999999/notes",
        headers: bearer(@read_token_raw), as: :json
    assert_response :not_found
  end

  # ── CREATE ────────────────────────────────────────────────────────────

  test "201 create a note (kind=note)" do
    assert_difference "Note.count", 1 do
      post "/api/v1/moves/#{@move.id}/notes",
           params: { note: { body: "API created note", kind: "note", source: "carlos" } },
           headers: bearer(@write_token_raw), as: :json
    end
    assert_response :created
    body = json_body
    assert_equal "API created note", body["body"]
    assert_equal "note", body["kind"]
  end

  test "client-supplied source is ignored — provenance is derived from the token" do
    post "/api/v1/moves/#{@move.id}/notes",
         params: { note: { body: "no impersonation", source: "carlos" } },
         headers: bearer(@write_token_raw), as: :json
    assert_response :created
    # Token is named "notes_write" (not a known source) -> defaults to "agent",
    # never the client-claimed "carlos".
    assert_equal "agent", json_body["source"]
  end

  test "201 create a prompt note (kind=prompt — agents save prompts)" do
    assert_difference "Note.count", 1 do
      post "/api/v1/moves/#{@move.id}/notes",
           params: { note: { body: "What next?", kind: "prompt", source: "agent" } },
           headers: bearer(@write_token_raw), as: :json
    end
    assert_response :created
    assert_equal "prompt", json_body["kind"]
  end

  test "422 create without body" do
    post "/api/v1/moves/#{@move.id}/notes",
         params: { note: { kind: "note" } },
         headers: bearer(@write_token_raw), as: :json
    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_body.dig("error", "code")
  end

  test "422 create with invalid kind" do
    post "/api/v1/moves/#{@move.id}/notes",
         params: { note: { body: "x", kind: "bogus" } },
         headers: bearer(@write_token_raw), as: :json
    assert_response :unprocessable_entity
  end

  # ── SEARCH ────────────────────────────────────────────────────────────

  test "search returns local results when METIS_CLI is unset" do
    get "/api/v1/notes/search?q=ATL",
        headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    body = json_body
    assert body.key?("notes"), "Response should have notes key"
    assert body.key?("source"), "Response should have source key"
    assert body.key?("query"), "Response should have query key"
    assert_equal "ATL", body["query"]
    # At least one local note should match (body contains "ATL")
    assert body["notes"].any? { |n| n["body"]&.include?("ATL") },
      "Should return local notes matching the query"
    # source should include 'local'
    assert_includes body["source"], "local"
  end

  test "search returns empty notes array for no matches" do
    get "/api/v1/notes/search?q=xyzzy_no_match_ever",
        headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    assert_equal [], json_body["notes"]
  end

  private

  def bearer(raw_token)
    { "Authorization" => "Bearer #{raw_token}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end
