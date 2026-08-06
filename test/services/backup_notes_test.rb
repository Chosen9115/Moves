require "test_helper"

class BackupNotesTest < ActiveSupport::TestCase
  # ── Exporter includes notes ────────────────────────────────────────────

  test "BackupExporter includes notes key with note data" do
    payload = BackupExporter.call

    assert payload.key?(:notes), "Payload should include a :notes key"
    assert payload[:notes].is_a?(Array)

    # Fixture notes should be present
    uuids = payload[:notes].map { |n| n[:uuid] }
    assert_includes uuids, notes(:atl_note_one).uuid
    assert_includes uuids, notes(:atl_prompt_one).uuid
  end

  test "BackupExporter note payload has required fields" do
    payload = BackupExporter.call
    note_payload = payload[:notes].find { |n| n[:uuid] == notes(:atl_note_one).uuid }

    assert note_payload, "atl_note_one should be in the export"
    assert_equal notes(:atl_note_one).body,   note_payload[:body]
    assert_equal "note",                       note_payload[:kind]
    assert_equal "carlos",                     note_payload[:source]
    assert_equal moves(:atl_pitch).uuid,       note_payload[:move_uuid]
  end

  test "BackupExporter preserves legacy notes field on moves for backward compat" do
    payload = BackupExporter.call
    move_payload = payload[:moves].find { |m| m[:uuid] == moves(:atl_pitch).uuid }

    assert move_payload, "atl_pitch should be in moves export"
    # The legacy :notes column field should still appear on each move row
    assert move_payload.key?(:notes),
      "moves[] should still include the legacy :notes field for backward compat"
  end

  # ── Importer restores notes ────────────────────────────────────────────

  test "BackupImporter round-trips notes" do
    # Capture uuid before deletion
    atl_note_uuid   = notes(:atl_note_one).uuid
    atl_note_body   = notes(:atl_note_one).body

    # Capture the current export
    json = JSON.generate(BackupExporter.call)

    # Destroy all notes, moves, campaigns (order matters for FKs)
    Note.delete_all
    MoveSignal.delete_all
    Move.delete_all
    Campaign.delete_all

    assert_equal 0, Note.count

    BackupImporter.call(json)

    # All notes from fixtures (3 in total) should be restored
    assert_equal 3, Note.count

    restored = Note.find_by(uuid: atl_note_uuid)
    assert restored, "atl_note_one should be restored"
    assert_equal atl_note_body, restored.body
    assert_equal "note",        restored.kind
    assert_equal "carlos",      restored.source
  end

  test "BackupImporter upserts notes — second import does not duplicate" do
    json = JSON.generate(BackupExporter.call)
    # First import
    Note.delete_all
    MoveSignal.delete_all
    Move.delete_all
    Campaign.delete_all
    BackupImporter.call(json)

    count_after_first = Note.count

    # Second import (idempotent)
    BackupImporter.call(json)
    assert_equal count_after_first, Note.count,
      "Second import should not create duplicate notes"
  end

  test "BackupImporter accepts payload without notes key (backward compat)" do
    payload = {
      "campaigns" => [],
      "moves"     => [],
      "signals"   => []
      # deliberately no "notes" key
    }
    # Should not raise even if notes key is missing
    assert_nothing_raised do
      BackupImporter.call(JSON.generate(payload))
    end
  end
end
