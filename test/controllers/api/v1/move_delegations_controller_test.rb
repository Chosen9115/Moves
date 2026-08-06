require "test_helper"

class Api::V1::MoveDelegationsControllerTest < ActionDispatch::IntegrationTest
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
    # Ensure move starts in "none" delegation state
    @move.update_columns(delegation_state: "none", assignee: nil,
                         delegation_id: nil, delegation_result: nil,
                         delegated_at: nil, reported_at: nil)
  end

  # ===========================================================================
  # DELEGATE
  # ===========================================================================

  test "403 when token lacks moves:write for delegate" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :forbidden
  end

  test "delegate issues a delegation_id and sets state=delegated" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok

    d = json_body.dig("delegation")
    assert_equal "darwin", d["assignee"]
    assert_equal "delegated", d["delegation_state"]
    # delegation_id + result are top-level on delegation-scoped responses (not in
    # the shared _move "delegation" block that moves:read tokens see).
    assert json_body["delegation_id"].present?
    assert d["delegated_at"].present?
    assert_nil d["reported_at"]
    assert_nil json_body["delegation_result"]

    @move.reload
    assert_equal "darwin", @move.assignee
    assert_equal "delegated", @move.delegation_state
    assert @move.delegation_id.present?
  end

  test "re-delegate issues a NEW delegation_id when not in-flight" do
    # First delegation
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok
    first_id = json_body["delegation_id"]

    # Move to done so it's not in-flight
    @move.update_columns(delegation_state: "done")

    # Re-delegate
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok
    second_id = json_body["delegation_id"]

    assert second_id.present?
    assert_not_equal first_id, second_id
  end

  test "re-delegate allowed when state=none" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok
  end

  test "re-delegate allowed when state=blocked" do
    @move.update_columns(delegation_state: "blocked")
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "olympus" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok
    assert_equal "olympus", json_body.dig("delegation", "assignee")
  end

  test "409 when trying to delegate an in-flight move" do
    @move.update_columns(delegation_state: "accepted", assignee: "darwin",
                         delegation_id: "abc123", delegated_at: 1.hour.ago)
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "olympus" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :conflict
    assert_equal "conflict", json_body.dig("error", "code")
  end

  test "422 when assignee is blank" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_argument", json_body.dig("error", "code")
  end

  test "404 when move not found for delegate" do
    post "/api/v1/moves/999999/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :not_found
  end

  test "delegate response includes delegation fields" do
    post "/api/v1/moves/#{@move.id}/delegate",
         params: { assignee: "darwin" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok
    body = json_body
    assert body.key?("id")
    assert body.key?("title")
    assert body.key?("delegation")
    assert body["delegation_id"].present?
  end

  # ===========================================================================
  # CLAIM
  # ===========================================================================

  test "403 when token lacks delegation:write for claim" do
    @move.update_columns(delegation_state: "delegated", assignee: "darwin",
                         delegation_id: SecureRandom.urlsafe_base64(16),
                         delegated_at: 1.minute.ago)
    post "/api/v1/moves/#{@move.id}/claim",
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :forbidden
  end

  test "200 claim succeeds and sets state=accepted" do
    @move.update_columns(delegation_state: "delegated", assignee: "darwin",
                         delegation_id: SecureRandom.urlsafe_base64(16),
                         delegated_at: 1.minute.ago)
    post "/api/v1/moves/#{@move.id}/claim",
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    assert_equal "accepted", json_body.dig("delegation", "delegation_state")

    @move.reload
    assert_equal "accepted", @move.delegation_state
  end

  test "409 on second claim (atomic claim prevents double-grab)" do
    @move.update_columns(delegation_state: "delegated", assignee: "darwin",
                         delegation_id: SecureRandom.urlsafe_base64(16),
                         delegated_at: 1.minute.ago)

    # First claim succeeds
    post "/api/v1/moves/#{@move.id}/claim",
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok

    # Second claim fails — already accepted
    post "/api/v1/moves/#{@move.id}/claim",
         headers: bearer(@darwin_raw), as: :json
    assert_response :conflict
    assert_equal "conflict", json_body.dig("error", "code")
  end

  test "409 when move not assigned to claiming agent" do
    @move.update_columns(delegation_state: "delegated", assignee: "olympus",
                         delegation_id: SecureRandom.urlsafe_base64(16),
                         delegated_at: 1.minute.ago)
    post "/api/v1/moves/#{@move.id}/claim",
         headers: bearer(@darwin_raw), as: :json
    assert_response :conflict
  end

  test "409 when move is not in delegated state (e.g. none)" do
    post "/api/v1/moves/#{@move.id}/claim",
         headers: bearer(@darwin_raw), as: :json
    assert_response :conflict
  end

  test "404 when move not found for claim" do
    post "/api/v1/moves/999999/claim",
         headers: bearer(@darwin_raw), as: :json
    assert_response :not_found
  end

  # ===========================================================================
  # CALLBACK
  # ===========================================================================

  def setup_delegated_move(state: "accepted")
    @delegation_id = SecureRandom.urlsafe_base64(16)
    @move.update_columns(
      delegation_state: state,
      assignee:         "darwin",
      delegation_id:    @delegation_id,
      delegated_at:     1.hour.ago,
      reported_at:      nil
    )
  end

  test "403 when token lacks delegation:write for callback" do
    setup_delegated_move
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done" },
         headers: bearer(@orchestrator_raw), as: :json
    assert_response :forbidden
  end

  test "403 when assignee != token name" do
    setup_delegated_move
    # olympus tries to callback for darwin's move
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done" },
         headers: bearer(@olympus_raw), as: :json
    assert_response :forbidden
    assert_equal "forbidden", json_body.dig("error", "code")
  end

  test "409 when delegation_id is stale/wrong" do
    setup_delegated_move
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: "wrong_id", status: "done" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :conflict
    assert_equal "conflict", json_body.dig("error", "code")
  end

  test "422 on invalid status" do
    setup_delegated_move
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "bogus" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_argument", json_body.dig("error", "code")
  end

  test "callback done completes the move (active stage)" do
    @move.update_columns(stage: Move.stages[:active])
    setup_delegated_move

    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done", result: "All done!" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok

    body = json_body
    assert_equal "done", body.dig("delegation", "delegation_state")
    assert_equal "completed", body["stage"]
    assert body.dig("delegation", "reported_at").present?

    @move.reload
    assert_equal "done", @move.delegation_state
    assert_equal "completed", @move.stage
    assert @move.completed_at.present?
    assert_equal "All done!", @move.delegation_result
  end

  # ── Callback requires a prior claim, and rejects replays (atomic guards) ──

  test "callback is rejected (409) if the move was not claimed first" do
    setup_delegated_move(state: "delegated") # delegated, NOT accepted
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :conflict
    assert_equal "delegated", @move.reload.delegation_state
  end

  test "a replayed callback after done is rejected (409) and cannot re-mutate" do
    setup_delegated_move(state: "accepted")
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done", result: "first" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok

    # Replay the same callback with the same (now-consumed) nonce.
    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "blocked", result: "tampered" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :conflict
    @move.reload
    assert_equal "done", @move.delegation_state
    assert_equal "first", @move.delegation_result
  end

  test "the delegation_id nonce is NOT exposed to a plain moves:read token" do
    setup_delegated_move(state: "delegated")
    get "/api/v1/moves/#{@move.id}", headers: bearer(@orchestrator_raw), as: :json
    assert_response :ok
    body = json_body
    # assignee/state are visible, but the callback capability nonce + result are not.
    assert_equal "darwin", body.dig("delegation", "assignee")
    assert_not body.key?("delegation_id")
    assert_not body["delegation"].key?("delegation_id")
  end

  test "callback done completes move when stage=inbox" do
    @move.update_columns(stage: Move.stages[:inbox])
    setup_delegated_move

    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    assert_equal "completed", json_body["stage"]
  end

  test "callback done completes move when stage=paused" do
    @move.update_columns(stage: Move.stages[:paused])
    setup_delegated_move

    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    assert_equal "completed", json_body["stage"]
  end

  test "callback done does NOT re-complete an already-completed move" do
    @move.update_columns(stage: Move.stages[:completed], completed_at: 2.days.ago)
    setup_delegated_move

    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "done" },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok
    # Stage stays completed, but delegation_state=done
    assert_equal "completed", json_body["stage"]
    assert_equal "done", json_body.dig("delegation", "delegation_state")
  end

  test "callback blocked records result but leaves stage unchanged" do
    original_stage = @move.stage
    setup_delegated_move

    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "blocked", result: "Stuck on auth." },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok

    body = json_body
    assert_equal "blocked", body.dig("delegation", "delegation_state")
    assert_equal original_stage, body["stage"]
    assert_equal "Stuck on auth.", body["delegation_result"]
    assert body.dig("delegation", "reported_at").present?
  end

  test "callback in_progress sets state and records a heartbeat (reported_at)" do
    setup_delegated_move

    post "/api/v1/moves/#{@move.id}/delegation/callback",
         params: { delegation_id: @delegation_id, status: "in_progress", result: "Working..." },
         headers: bearer(@darwin_raw), as: :json
    assert_response :ok

    body = json_body
    assert_equal "in_progress", body.dig("delegation", "delegation_state")
    # Every callback (incl. in_progress) is a heartbeat that resets the stall timer.
    assert body.dig("delegation", "reported_at").present?
  end

  test "404 when move not found for callback" do
    post "/api/v1/moves/999999/delegation/callback",
         params: { delegation_id: "abc", status: "done" },
         headers: bearer(@darwin_raw), as: :json
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
