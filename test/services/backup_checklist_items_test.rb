require "test_helper"

class BackupChecklistItemsTest < ActiveSupport::TestCase
  # ── Exporter includes checklist_items ─────────────────────────────────

  test "BackupExporter includes checklist_items key with item data" do
    payload = BackupExporter.call

    assert payload.key?(:checklist_items), "Payload should include a :checklist_items key"
    assert payload[:checklist_items].is_a?(Array)

    uuids = payload[:checklist_items].map { |i| i[:uuid] }
    assert_includes uuids, checklist_items(:atl_item_one).uuid
    assert_includes uuids, checklist_items(:atl_item_two).uuid
  end

  test "BackupExporter checklist_item payload has required fields" do
    payload = BackupExporter.call
    item_payload = payload[:checklist_items].find { |i| i[:uuid] == checklist_items(:atl_item_one).uuid }

    assert item_payload, "atl_item_one should be in the export"
    assert_equal checklist_items(:atl_item_one).title, item_payload[:title]
    assert_equal false, item_payload[:done]
    assert_equal moves(:atl_pitch).uuid, item_payload[:move_uuid]
    assert item_payload.key?(:position)
  end

  # ── Importer restores checklist_items ─────────────────────────────────

  test "BackupImporter round-trips checklist items" do
    atl_item_uuid  = checklist_items(:atl_item_one).uuid
    atl_item_title = checklist_items(:atl_item_one).title

    json = JSON.generate(BackupExporter.call)

    ChecklistItem.delete_all
    Note.delete_all
    MoveSignal.delete_all
    Move.delete_all
    Campaign.delete_all

    assert_equal 0, ChecklistItem.count

    BackupImporter.call(json)

    # All checklist items from fixtures (3) should be restored
    assert_equal 3, ChecklistItem.count

    restored = ChecklistItem.find_by(uuid: atl_item_uuid)
    assert restored, "atl_item_one should be restored"
    assert_equal atl_item_title, restored.title
    assert_equal false, restored.done
  end

  test "BackupImporter upserts checklist items — second import does not duplicate" do
    json = JSON.generate(BackupExporter.call)

    ChecklistItem.delete_all
    Note.delete_all
    MoveSignal.delete_all
    Move.delete_all
    Campaign.delete_all

    BackupImporter.call(json)
    count_after_first = ChecklistItem.count

    BackupImporter.call(json)
    assert_equal count_after_first, ChecklistItem.count,
      "Second import should not create duplicate checklist items"
  end

  test "BackupImporter accepts payload without checklist_items key (backward compat)" do
    payload = {
      "campaigns" => [],
      "moves"     => [],
      "signals"   => []
      # deliberately no "checklist_items" key
    }
    assert_nothing_raised do
      BackupImporter.call(JSON.generate(payload))
    end
  end
end
