class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :uuid, null: false
      t.string :name, null: false
      t.text :objective
      t.integer :status, null: false, default: 0
      t.decimal :total_ev, precision: 12, scale: 4
      t.decimal :momentum_score, precision: 8, scale: 4
      t.decimal :confidence_trend, precision: 8, scale: 4
      t.integer :active_move_count, null: false, default: 0

      t.timestamps
    end
    add_index :campaigns, :uuid, unique: true
    add_index :campaigns, :status
  end
end
