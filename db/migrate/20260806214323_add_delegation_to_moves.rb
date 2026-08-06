class AddDelegationToMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :moves, :assignee, :string
    add_column :moves, :delegation_state, :string, null: false, default: "none"
    add_column :moves, :delegation_id, :string
    add_column :moves, :delegation_result, :text
    add_column :moves, :delegated_at, :datetime
    add_column :moves, :reported_at, :datetime

    add_index :moves, :assignee
    add_index :moves, %i[assignee delegation_state]
  end
end
