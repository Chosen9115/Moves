class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :color, null: false, default: "#1E5C42"
      t.integer :cadence, default: 1
      t.text :objective
      t.string :uuid

      t.timestamps
    end

    add_index :projects, :uuid, unique: true
  end
end
