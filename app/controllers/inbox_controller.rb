class InboxController < ApplicationController
  def index
    @move = Move.new(stage: :inbox)
    # Inbox always shows ALL inbox moves — these are untriaged, pre-campaign items
    @inbox_moves = Move.where(stage: :inbox).includes(:campaign).order(created_at: :desc)
    @campaigns = Campaign.order(:name)
  end
end
