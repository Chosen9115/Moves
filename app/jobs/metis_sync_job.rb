# MetisSyncJob syncs a single Note to the Metis brain via MetisClient.
#
# Design choices:
# - Accepts note_id (not the body) so Solid Queue serialises just an integer.
# - Reloads the note at run-time; silently exits if already gone.
# - Skips prompts (kind != "note") — they are never synced.
# - Skips notes already fresh (metis_synced_at >= updated_at).
# - Uses update_columns (no callbacks) to set metis_synced_at, breaking
#   any potential re-enqueue loop from the after_commit hook.
# - Never raises — any error is logged and swallowed.
# - Deletions: Metis is append-only for notes; remote deletion is not attempted.
class MetisSyncJob < ApplicationJob
  queue_as :default

  def perform(note_id)
    note = Note.find_by(id: note_id)
    return unless note
    return unless note.kind == "note"  # prompts are not synced
    return if note.metis_synced_at.present? && note.metis_synced_at >= note.updated_at

    # The exact version we're about to sync. We stamp metis_synced_at with THIS
    # value (not Time.current) so a concurrent edit that bumps updated_at while we
    # shell out stays newer than metis_synced_at and re-syncs — no permanent staleness.
    synced_version = note.updated_at

    # Nothing to sync to (dev/test / Metis not configured): treat as done so we
    # don't retry forever. A later edit re-enqueues once METIS_CLI is set.
    unless MetisClient.configured?
      mark_synced(note, synced_version)
      return
    end

    # Configured: only mark synced when the put actually succeeded, so a transient
    # failure is left unsynced and retried on the note's next change.
    if MetisClient.put_page(slug: note.metis_slug, title: build_title(note), content: note.body)
      mark_synced(note, synced_version)
    end
  rescue StandardError => e
    Rails.logger.warn("[MetisSyncJob] Error syncing note #{note_id}: #{e.message}")
  end

  private

  # Update only the metis columns via update_columns (no callbacks -> no re-enqueue,
  # and updated_at is left untouched so a concurrent edit isn't reverted).
  def mark_synced(note, synced_version)
    note.update_columns(metis_slug: note.metis_slug, metis_synced_at: synced_version)
  end

  def build_title(note)
    move_title = note.move&.title.presence || "standalone"
    "Move note — #{move_title} (#{note.uuid[0..7]})"
  end
end
