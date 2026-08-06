require "test_helper"

class ChecklistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @move = moves(:atl_pitch)
    @item = checklist_items(:atl_item_one)
  end

  # ── Rendered forms use the nested checklist_item[...] param shape ──────
  # (regression: the forms previously submitted top-level params, which raised
  # ParameterMissing on real UI use even though the controller tests passed.)

  test "move show renders checklist forms with nested checklist_item param names" do
    get move_path(@move)
    assert_response :success
    assert_select "form input[name=?]", "checklist_item[title]"
    assert_select "form input[name=?]", "checklist_item[done]"
  end

  # ── CREATE ────────────────────────────────────────────────────────────

  test "creates a checklist item and redirects" do
    assert_difference "ChecklistItem.count", 1 do
      post move_checklist_items_path(@move),
           params: { checklist_item: { title: "New item from web" } }
    end
    assert_redirected_to move_path(@move)
    item = @move.checklist_items.unscoped.where(move: @move).order(created_at: :desc).first
    assert_equal "New item from web", item.title
    assert_equal false, item.done
  end

  test "responds with turbo_stream on create when turbo format requested" do
    assert_difference "ChecklistItem.count", 1 do
      post move_checklist_items_path(@move),
           params: { checklist_item: { title: "Turbo item" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  test "does not create item with blank title — redirects with alert" do
    assert_no_difference "ChecklistItem.count" do
      post move_checklist_items_path(@move),
           params: { checklist_item: { title: "" } }
    end
    assert_redirected_to move_path(@move)
  end

  # ── UPDATE (toggle done) ──────────────────────────────────────────────

  test "toggles done to true and redirects" do
    assert_equal false, @item.done
    patch move_checklist_item_path(@move, @item),
          params: { checklist_item: { done: true } }
    assert_redirected_to move_path(@move)
    assert_equal true, @item.reload.done
  end

  test "responds with turbo_stream on update when turbo format requested" do
    patch move_checklist_item_path(@move, @item),
          params: { checklist_item: { done: true } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  test "renames item title" do
    patch move_checklist_item_path(@move, @item),
          params: { checklist_item: { title: "Renamed title" } }
    assert_redirected_to move_path(@move)
    assert_equal "Renamed title", @item.reload.title
  end

  # ── DESTROY ───────────────────────────────────────────────────────────

  test "destroys a checklist item and redirects" do
    assert_difference "ChecklistItem.count", -1 do
      delete move_checklist_item_path(@move, @item)
    end
    assert_redirected_to move_path(@move)
  end

  test "responds with turbo_stream on destroy when turbo format requested" do
    assert_difference "ChecklistItem.count", -1 do
      delete move_checklist_item_path(@move, @item),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  # ── Auth guard ────────────────────────────────────────────────────────

  test "requires session — redirects to login when not signed in" do
    sign_out
    post move_checklist_items_path(@move), params: { checklist_item: { title: "sneaky" } }
    assert_redirected_to new_session_path
  end
end
