require "test_helper"

class Api::V1::ChecklistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @read_token_record, @read_token_raw = ApiToken.generate!(
      name: "checklist_read",  scopes: "moves:read"
    )
    @write_token_record, @write_token_raw = ApiToken.generate!(
      name: "checklist_write", scopes: "moves:read moves:write"
    )
    @wrong_scope_record, @wrong_scope_raw = ApiToken.generate!(
      name: "notes_only",      scopes: "notes:read notes:write"
    )
    @move  = moves(:atl_pitch)
    @item  = checklist_items(:atl_item_one)
  end

  # ── Scope 403s ────────────────────────────────────────────────────────

  test "403 on index without moves:read scope" do
    get "/api/v1/moves/#{@move.id}/checklist_items",
        headers: bearer(@wrong_scope_raw), as: :json
    assert_response :forbidden
    assert_equal "forbidden", json_body.dig("error", "code")
  end

  test "403 on create without moves:write scope" do
    post "/api/v1/moves/#{@move.id}/checklist_items",
         params: { checklist_item: { title: "Nope" } },
         headers: bearer(@read_token_raw), as: :json
    assert_response :forbidden
  end

  test "403 on update without moves:write scope" do
    patch "/api/v1/moves/#{@move.id}/checklist_items/#{@item.id}",
          params: { checklist_item: { done: true } },
          headers: bearer(@read_token_raw), as: :json
    assert_response :forbidden
  end

  test "403 on destroy without moves:write scope" do
    delete "/api/v1/moves/#{@move.id}/checklist_items/#{@item.id}",
           headers: bearer(@read_token_raw), as: :json
    assert_response :forbidden
  end

  # ── INDEX ─────────────────────────────────────────────────────────────

  test "200 index returns checklist_items array for the move" do
    get "/api/v1/moves/#{@move.id}/checklist_items",
        headers: bearer(@read_token_raw), as: :json
    assert_response :ok
    body = json_body
    assert body.key?("checklist_items"), "Response should have a checklist_items key"
    uuids = body["checklist_items"].map { |i| i["uuid"] }
    assert_includes uuids, checklist_items(:atl_item_one).uuid
    assert_includes uuids, checklist_items(:atl_item_two).uuid
    assert_not_includes uuids, checklist_items(:cabalo_item_one).uuid
  end

  test "404 index when move does not exist" do
    get "/api/v1/moves/999999/checklist_items",
        headers: bearer(@read_token_raw), as: :json
    assert_response :not_found
    assert_equal "not_found", json_body.dig("error", "code")
  end

  # ── CREATE ────────────────────────────────────────────────────────────

  test "201 create a checklist item" do
    assert_difference "ChecklistItem.count", 1 do
      post "/api/v1/moves/#{@move.id}/checklist_items",
           params: { checklist_item: { title: "API created item" } },
           headers: bearer(@write_token_raw), as: :json
    end
    assert_response :created
    body = json_body
    assert_equal "API created item", body["title"]
    assert_equal false, body["done"]
  end

  test "422 create without title" do
    post "/api/v1/moves/#{@move.id}/checklist_items",
         params: { checklist_item: { done: false } },
         headers: bearer(@write_token_raw), as: :json
    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_body.dig("error", "code")
  end

  test "404 create when move does not exist" do
    post "/api/v1/moves/999999/checklist_items",
         params: { checklist_item: { title: "Nope" } },
         headers: bearer(@write_token_raw), as: :json
    assert_response :not_found
  end

  # ── UPDATE ────────────────────────────────────────────────────────────

  test "200 update toggles done" do
    assert_equal false, @item.done
    patch "/api/v1/moves/#{@move.id}/checklist_items/#{@item.id}",
          params: { checklist_item: { done: true } },
          headers: bearer(@write_token_raw), as: :json
    assert_response :ok
    assert_equal true, json_body["done"]
    assert_equal true, @item.reload.done
  end

  test "200 update renames title" do
    patch "/api/v1/moves/#{@move.id}/checklist_items/#{@item.id}",
          params: { checklist_item: { title: "Renamed via API" } },
          headers: bearer(@write_token_raw), as: :json
    assert_response :ok
    assert_equal "Renamed via API", json_body["title"]
  end

  test "404 update when item does not exist" do
    patch "/api/v1/moves/#{@move.id}/checklist_items/999999",
          params: { checklist_item: { done: true } },
          headers: bearer(@write_token_raw), as: :json
    assert_response :not_found
    assert_equal "not_found", json_body.dig("error", "code")
  end

  test "422 update with blank title" do
    patch "/api/v1/moves/#{@move.id}/checklist_items/#{@item.id}",
          params: { checklist_item: { title: "" } },
          headers: bearer(@write_token_raw), as: :json
    assert_response :unprocessable_entity
    assert_equal "validation_failed", json_body.dig("error", "code")
  end

  # ── DESTROY ───────────────────────────────────────────────────────────

  test "204 destroy removes the item" do
    assert_difference "ChecklistItem.count", -1 do
      delete "/api/v1/moves/#{@move.id}/checklist_items/#{@item.id}",
             headers: bearer(@write_token_raw), as: :json
    end
    assert_response :no_content
  end

  test "404 destroy when item does not exist" do
    delete "/api/v1/moves/#{@move.id}/checklist_items/999999",
           headers: bearer(@write_token_raw), as: :json
    assert_response :not_found
    assert_equal "not_found", json_body.dig("error", "code")
  end

  private

  def bearer(raw_token)
    { "Authorization" => "Bearer #{raw_token}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end
