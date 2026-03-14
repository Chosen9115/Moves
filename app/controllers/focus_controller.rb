class FocusController < ApplicationController
  def index
    @quick_move = Move.new(stage: :inbox)
    @campaigns  = scoped_campaigns.order(:name)
    buckets = FocusClassifier.call(scoped_moves)
    @best_moves_now = buckets[:best_moves_now]
    @strategic_bets = buckets[:strategic_bets]
    @needs_a_call   = buckets[:needs_a_call]

    current_week = Date.today.cweek
    dismissed    = session[:brief_dismissed_week].to_i
    @show_brief  = (Date.today.wday == 1 || dismissed != current_week) &&
                   (Move.exists? || Campaign.exists?)

    @brief = WeeklyBriefService.call if @show_brief
  end

  def dismiss_brief
    session[:brief_dismissed_week] = Date.today.cweek
    redirect_to focus_path
  end
end
