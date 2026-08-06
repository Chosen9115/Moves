class BackfillMoveNotesToNotesTable < ActiveRecord::Migration[8.1]
  def up
    # One-shot backfill: for every Move with non-blank notes, create one Note row.
    # Idempotent: skip moves that already have a note linked to them.
    execute <<~SQL
      INSERT INTO notes (uuid, move_id, body, kind, source, created_at, updated_at)
      SELECT
        lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
          substr(lower(hex(randomblob(2))), 2) || '-' ||
          substr('89ab', abs(random()) % 4 + 1, 1) ||
          substr(lower(hex(randomblob(2))), 2) || '-' ||
          lower(hex(randomblob(6))),
        m.id,
        m.notes,
        'note',
        'carlos',
        m.created_at,
        m.updated_at
      FROM moves m
      WHERE m.notes IS NOT NULL
        AND trim(m.notes) != ''
        AND NOT EXISTS (SELECT 1 FROM notes n WHERE n.move_id = m.id)
    SQL
  end

  def down
    # Non-reversible data migration — notes table is dropped by CreateNotes rollback anyway
  end
end
