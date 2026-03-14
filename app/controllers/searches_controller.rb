class SearchesController < ApplicationController
  def index
    q = params[:q].to_s.strip
    pattern = "%#{q.downcase}%"

    moves = scoped_moves.where("lower(title) LIKE ?", pattern)
                .where(stage: %i[active inbox paused])
                .includes(campaign: :project)
                .order(updated_at: :desc)
                .limit(7)

    campaigns = scoped_campaigns.where("lower(name) LIKE ?", pattern)
                        .includes(:project)
                        .order(:name)
                        .limit(4)

    render json: {
      moves: moves.map { |m|
        rec = m.recommendation.presence || RecommendationEngine.call(m)
        { id: m.id, title: m.title, url: move_path(m), rec: rec,
          project_color: m.campaign&.project&.color }
      },
      campaigns: campaigns.map { |c|
        { id: c.id, name: c.name, url: campaign_path(c),
          project_color: c.project&.color }
      }
    }
  end
end
