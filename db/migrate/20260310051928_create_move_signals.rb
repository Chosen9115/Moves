class CreateMoveSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :signals do |t|
      t.string :uuid, null: false
      t.references :move, null: false, foreign_key: true
      t.string :signal_type, null: false
      t.text :note
      t.integer :direction, null: false, default: 2
      t.integer :magnitude, null: false, default: 1

      t.timestamps
    end
    add_index :signals, :uuid, unique: true
    add_index :signals, :direction
  end
end
