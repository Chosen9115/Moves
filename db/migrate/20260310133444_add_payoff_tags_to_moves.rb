class AddPayoffTagsToMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :moves, :payoff_tags, :json, null: false, default: []
  end
end
