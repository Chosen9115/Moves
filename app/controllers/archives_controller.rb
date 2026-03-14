class ArchivesController < ApplicationController
  def index
    @archived_moves = Move.where(stage: :archived).includes(:campaign).order(updated_at: :desc)
    @completed_moves = Move.where(stage: :completed).includes(:campaign).order(completed_at: :desc)
  end
end
