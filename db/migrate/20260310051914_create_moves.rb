class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves do |t|
      t.string :uuid, null: false
      t.string :title, null: false
      t.text :description
      t.references :campaign, null: true, foreign_key: true
      t.integer :move_type, null: false, default: 0
      t.integer :stage, null: false, default: 0
      t.text :success_definition
      t.integer :payoff_type
      t.decimal :payoff_value_raw, precision: 12, scale: 2
      t.integer :payoff_value_normalized
      t.integer :base_rate
      t.integer :subjective_probability
      t.integer :adjusted_probability
      t.integer :effort_minutes
      t.json :advantages, null: false, default: []
      t.json :blockers, null: false, default: []
      t.decimal :ev_score, precision: 12, scale: 4
      t.decimal :confidence_score, precision: 8, scale: 4
      t.string :recommendation
      t.datetime :due_date
      t.datetime :completed_at
      t.text :notes

      t.timestamps
    end
    add_index :moves, :uuid, unique: true
    add_index :moves, :stage
    add_index :moves, :recommendation
    add_index :moves, :payoff_value_normalized
  end
end
