class CreateChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_items do |t|
      t.integer  :move_id, null: false
      t.string   :uuid, null: false
      t.string   :title, null: false
      t.boolean  :done, default: false, null: false
      t.integer  :position

      t.timestamps
    end

    add_index :checklist_items, :move_id
    add_index :checklist_items, :uuid, unique: true
    add_foreign_key :checklist_items, :moves
  end
end
