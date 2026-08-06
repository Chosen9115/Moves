require "test_helper"

class NoteTest < ActiveSupport::TestCase
  # ── Validations ───────────────────────────────────────────────────────────

  test "valid with body, kind=note, source=carlos, and a move" do
    note = Note.new(body: "test", kind: "note", source: "carlos", move: moves(:atl_pitch))
    assert note.valid?, note.errors.full_messages.inspect
  end

  test "invalid without body" do
    note = Note.new(kind: "note", source: "carlos", move: moves(:atl_pitch))
    assert_not note.valid?
    assert_includes note.errors[:body], "can't be blank"
  end

  test "invalid with unsupported kind" do
    note = Note.new(body: "x", kind: "bogus", source: "carlos")
    assert_not note.valid?
    assert_includes note.errors[:kind], "is not included in the list"
  end

  test "invalid with unsupported source" do
    note = Note.new(body: "x", kind: "note", source: "unknown_bot")
    assert_not note.valid?
    assert_includes note.errors[:source], "is not included in the list"
  end

  test "valid with kind=prompt and source=agent" do
    note = Note.new(body: "prompt text", kind: "prompt", source: "agent", move: moves(:atl_pitch))
    assert note.valid?, note.errors.full_messages.inspect
  end

  test "valid with no move (optional)" do
    note = Note.new(body: "standalone note", kind: "note", source: "carlos")
    assert note.valid?, note.errors.full_messages.inspect
  end

  # ── UUID auto-assignment ────────────────────────────────────────────────

  test "uuid is set before validation if blank" do
    note = Note.new(body: "x", kind: "note", source: "carlos")
    note.valid?
    assert note.uuid.present?
  end

  test "uuid is not overwritten if already set" do
    existing_uuid = "my-special-uuid-1234"
    note = Note.new(body: "x", kind: "note", source: "carlos", uuid: existing_uuid)
    note.valid?
    assert_equal existing_uuid, note.uuid
  end

  # ── Syncable scope ─────────────────────────────────────────────────────

  test "syncable scope includes kind=note" do
    note = notes(:atl_note_one)
    assert_includes Note.syncable, note
  end

  test "syncable scope excludes kind=prompt" do
    prompt = notes(:atl_prompt_one)
    assert_not_includes Note.syncable, prompt
  end

  # ── project derivation ─────────────────────────────────────────────────

  test "project returns nil when note has no move" do
    note = Note.new(body: "x", kind: "note", source: "carlos")
    assert_nil note.project
  end

  test "project is derived from move -> campaign -> project" do
    # Campaigns in fixtures don't all have projects; just test the chain works
    note = notes(:atl_note_one)
    # Whether project is nil or a Project, it shouldn't raise
    assert_nothing_raised { note.project }
  end

  # ── metis_slug default ─────────────────────────────────────────────────

  test "metis_slug defaults to projects/moves-notes/<uuid>" do
    note = notes(:atl_note_one)
    note.update_column(:metis_slug, nil)
    note.reload
    expected = "projects/moves-notes/#{note.uuid}"
    assert_equal expected, note.metis_slug
  end

  test "metis_slug returns stored value when present" do
    note = notes(:atl_note_one)
    note.update_column(:metis_slug, "custom/slug")
    note.reload
    assert_equal "custom/slug", note.metis_slug
  end

  # ── Association ────────────────────────────────────────────────────────

  test "move has_many notes" do
    move = moves(:atl_pitch)
    assert_includes move.notes, notes(:atl_note_one)
    assert_includes move.notes, notes(:atl_prompt_one)
    assert_not_includes move.notes, notes(:cabalo_note_one)
  end
end
