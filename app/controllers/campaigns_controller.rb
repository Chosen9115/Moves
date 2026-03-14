class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show edit update destroy]

  def index
    @campaigns = scoped_campaigns.includes(:moves).order(updated_at: :desc)
    @campaign = Campaign.new
  end

  def show
    @moves = @campaign.moves.includes(:move_signals).order(updated_at: :desc)
    @top_move = @campaign.top_next_move
  end

  def new
    @campaign = Campaign.new
  end

  def create
    @campaign = Campaign.new(campaign_params)

    if @campaign.save
      redirect_to campaign_path(@campaign), notice: "Campaign created."
    else
      @campaigns = Campaign.includes(:moves).order(updated_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @campaign.update(campaign_params)
      redirect_to campaign_path(@campaign), notice: "Campaign updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_path, notice: "Campaign deleted."
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :objective, :status, :project_id)
  end
end
