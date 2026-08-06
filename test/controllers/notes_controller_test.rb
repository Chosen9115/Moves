require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @move = moves(:atl_pitch)
    @note = notes(:atl_note_one)
  end

  # ── CREATE ────────────────────────────────────────────────────────────

  test "creates a note on a move and redirects" do
    assert_difference "Note.count", 1 do
      post move_notes_path(@move),
           params: { note: { body: "New note from web" } }
    end
    assert_redirected_to move_path(@move)
    note = @move.notes.order(created_at: :desc).first
    assert_equal "New note from web", note.body
    assert_equal "carlos", note.source
    assert_equal "note", note.kind
  end

  test "responds with turbo_stream on create when turbo format requested" do
    assert_difference "Note.count", 1 do
      post move_notes_path(@move),
           params: { note: { body: "Turbo note" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  test "does not create note with blank body — redirects with alert" do
    assert_no_difference "Note.count" do
      post move_notes_path(@move),
           params: { note: { body: "" } }
    end
    assert_redirected_to move_path(@move)
  end

  # ── DESTROY ───────────────────────────────────────────────────────────

  test "destroys a note and redirects" do
    assert_difference "Note.count", -1 do
      delete move_note_path(@move, @note)
    end
    assert_redirected_to move_path(@move)
  end

  test "responds with turbo_stream on destroy when turbo format requested" do
    assert_difference "Note.count", -1 do
      delete move_note_path(@move, @note),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  # ── Auth guard ────────────────────────────────────────────────────────

  test "requires session — redirects to login when not signed in" do
    sign_out
    post move_notes_path(@move), params: { note: { body: "sneaky" } }
    assert_redirected_to new_session_path
  end
end
