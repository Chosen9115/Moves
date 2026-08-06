class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.string   :uuid, null: false
      t.references :move, null: true, foreign_key: true, index: true
      t.text     :body
      t.string   :kind,   default: "note"
      t.string   :source, default: "carlos"
      t.string   :metis_slug
      t.datetime :metis_synced_at

      t.timestamps
    end

    add_index :notes, :uuid, unique: true
  end
end
