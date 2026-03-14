class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_current_project
  helper_method :app_preference, :payoff_options, :probability_options, :effort_options,
                :current_project, :all_projects, :scoped_moves, :scoped_campaigns

  private

  def set_current_project
    @all_projects = Project.order(:name)
    if params.key?(:project_id)
      if params[:project_id].present?
        @current_project = Project.find_by(id: params[:project_id])
        session[:project_id] = @current_project&.id
      else
        @current_project = nil
        session.delete(:project_id)
      end
    elsif session[:project_id].present?
      @current_project = Project.find_by(id: session[:project_id])
    end
  end

  def current_project = @current_project
  def all_projects    = @all_projects

  def scoped_moves
    current_project ? current_project.moves : Move.all
  end

  def scoped_campaigns
    current_project ? current_project.campaigns : Campaign.all
  end

  def app_preference
    @app_preference ||= AppPreference.current
  end

  def payoff_options
    Move::PAYOFF_SCALE
  end

  def probability_options
    Move::PROBABILITY_SCALE
  end

  def effort_options
    Move::EFFORT_SCALE
  end
end
