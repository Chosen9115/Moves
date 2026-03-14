class AddProjectIdToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaigns, :project, null: true, foreign_key: true
  end
end
