class RemoveNotesFromMoves < ActiveRecord::Migration[8.1]
  # The legacy free-text moves.notes column has been backfilled into the notes
  # table (see BackfillMoveNotesToNotesTable) and is no longer written. Remove it
  # because it collides with Move's has_many :notes association.
  def change
    remove_column :moves, :notes, :text
  end
end
