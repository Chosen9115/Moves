require "test_helper"

class MetisSyncJobTest < ActiveSupport::TestCase
  setup do
    # Ensure METIS_CLI is never set in tests — all calls must go through stub
    @original_metis_cli = ENV.delete("METIS_CLI")

    @move = moves(:atl_pitch)
    @note = notes(:atl_note_one)
    # Reset metis sync state
    @note.update_columns(metis_slug: nil, metis_synced_at: nil)
    @note.reload
  end

  teardown do
    ENV["METIS_CLI"] = @original_metis_cli if @original_metis_cli
  end

  # Safe stub helper: temporarily replaces MetisClient.put_page
  # using a module so the original method is never removed.
  def with_put_page_stub(implementation, &block)
    stub_mod = Module.new do
      define_method(:put_page, implementation)
    end
    MetisClient.singleton_class.prepend(stub_mod)
    yield
  ensure
    # Remove the prepended stub module's method — original is still below it
    stub_mod.instance_eval { remove_method(:put_page) }
  end

  # ── Skips prompts ─────────────────────────────────────────────────────

  test "skips notes with kind=prompt — does not call MetisClient" do
    prompt = notes(:atl_prompt_one)
    was_called = false

    with_put_page_stub(->(slug:, title:, content:) { was_called = true; true }) do
      MetisSyncJob.new.perform(prompt.id)
    end

    assert_not was_called, "MetisClient should not be called for prompts"
  end

  # ── Skips if already fresh ────────────────────────────────────────────

  test "skips note that is already synced (metis_synced_at >= updated_at)" do
    @note.update_columns(metis_synced_at: 1.hour.from_now)
    @note.reload

    was_called = false
    with_put_page_stub(->(slug:, title:, content:) { was_called = true; true }) do
      MetisSyncJob.new.perform(@note.id)
    end

    assert_not was_called, "MetisClient should not be called when note is already fresh"
  end

  # ── Syncs and sets metis_synced_at ────────────────────────────────────

  test "calls MetisClient.put_page with per-note slug and sets metis_synced_at" do
    ENV["METIS_CLI"] = "/usr/bin/metis" # configured? -> true so the put_page path runs
    put_page_calls = []

    with_put_page_stub(->(slug:, title:, content:) {
      put_page_calls << { slug: slug, title: title, content: content }
      true
    }) do
      MetisSyncJob.new.perform(@note.id)
    end

    assert_equal 1, put_page_calls.size, "put_page should be called exactly once"

    call = put_page_calls.first
    expected_slug = "projects/moves-notes/#{@note.uuid}"
    assert_equal expected_slug, call[:slug],
      "Slug must be projects/moves-notes/<uuid> so re-put replaces the same page"
    assert_equal @note.body, call[:content]

    @note.reload
    assert @note.metis_synced_at.present?,
      "metis_synced_at should be set after successful sync"
    assert_equal expected_slug, @note.metis_slug
  end

  # ── Graceful: non-existent note ──────────────────────────────────────

  test "returns without error when note does not exist" do
    assert_nothing_raised do
      MetisSyncJob.new.perform(999_999)
    end
  end

  # ── Never raises ─────────────────────────────────────────────────────

  test "marks synced without calling put_page when METIS_CLI is unset" do
    # With Metis not configured there is nothing to sync to, so the job marks the
    # note as done (avoids infinite retries) and never calls put_page.
    was_called = false
    with_put_page_stub(->(slug:, title:, content:) { was_called = true; true }) do
      assert_nothing_raised { MetisSyncJob.new.perform(@note.id) }
    end

    assert_not was_called, "put_page must not be called when METIS_CLI is unset"
    @note.reload
    assert @note.metis_synced_at.present?,
      "metis_synced_at should be set on the not-configured path"
  end

  test "does NOT mark synced when configured but put_page fails (so it can retry)" do
    ENV["METIS_CLI"] = "/usr/bin/metis"
    with_put_page_stub(->(slug:, title:, content:) { nil }) do
      MetisSyncJob.new.perform(@note.id)
    end

    @note.reload
    assert_nil @note.metis_synced_at,
      "a failed put must leave the note unsynced so a later change retries"
  end

  test "does not raise when MetisClient.put_page raises an unexpected error" do
    with_put_page_stub(->(slug:, title:, content:) { raise RuntimeError, "boom" }) do
      assert_nothing_raised do
        MetisSyncJob.new.perform(@note.id)
      end
    end
  end
end
