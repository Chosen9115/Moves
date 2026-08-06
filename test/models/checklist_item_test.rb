require "test_helper"

class ChecklistItemTest < ActiveSupport::TestCase
  # ── Validations ─────────────────────────────────────────────────────────

  test "valid with title and move" do
    item = ChecklistItem.new(title: "Do something", move: moves(:atl_pitch))
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "invalid without title" do
    item = ChecklistItem.new(move: moves(:atl_pitch))
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
  end

  test "invalid without move" do
    item = ChecklistItem.new(title: "No move")
    assert_not item.valid?
  end

  # ── UUID auto-assignment ────────────────────────────────────────────────

  test "uuid is set before validation if blank" do
    item = ChecklistItem.new(title: "test", move: moves(:atl_pitch))
    item.valid?
    assert item.uuid.present?
  end

  test "uuid is not overwritten if already set" do
    existing_uuid = "my-fixed-uuid-4321"
    item = ChecklistItem.new(title: "test", move: moves(:atl_pitch), uuid: existing_uuid)
    item.valid?
    assert_equal existing_uuid, item.uuid
  end

  # ── Done default ────────────────────────────────────────────────────────

  test "done defaults to false" do
    item = ChecklistItem.create!(title: "New task", move: moves(:atl_pitch))
    assert_equal false, item.done
  end

  # ── Auto-position assignment ────────────────────────────────────────────

  test "auto-assigns position as max + 1 within the move" do
    move = moves(:atl_pitch)
    # atl_item_one has position 1, atl_item_two has position 2 from fixtures
    max_before = move.checklist_items.unscoped.where(move: move).maximum(:position)
    item = move.checklist_items.create!(title: "New auto-positioned")
    assert_equal max_before + 1, item.position
  end

  test "first item on a move gets position 1" do
    move = moves(:cabalo_followup)
    # Delete existing items to ensure we start fresh
    move.checklist_items.delete_all
    item = move.checklist_items.create!(title: "First item")
    assert_equal 1, item.position
  end

  test "explicit position is preserved" do
    item = ChecklistItem.create!(title: "Explicit pos", move: moves(:atl_pitch), position: 99)
    assert_equal 99, item.position
  end

  # ── Ordering ────────────────────────────────────────────────────────────

  test "default scope orders by position then id" do
    move = moves(:atl_pitch)
    items = move.checklist_items.to_a
    positions = items.map(&:position)
    assert_equal positions.sort, positions
  end

  # ── Association ─────────────────────────────────────────────────────────

  test "move has_many checklist_items" do
    move = moves(:atl_pitch)
    assert_includes move.checklist_items, checklist_items(:atl_item_one)
    assert_includes move.checklist_items, checklist_items(:atl_item_two)
    assert_not_includes move.checklist_items, checklist_items(:cabalo_item_one)
  end

  test "checklist_items are destroyed with move" do
    move = moves(:atl_pitch)
    item_id = checklist_items(:atl_item_one).id
    move.destroy
    assert_nil ChecklistItem.find_by(id: item_id)
  end
end
