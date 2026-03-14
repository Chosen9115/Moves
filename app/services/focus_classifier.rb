class FocusClassifier
  BEST_LABELS = [ "Push now", "Good bet" ].freeze
  NEEDS_CALL_LABELS = [ "Needs signal", "Probably dead", "Reassess" ].freeze

  def self.call(scope = Move.all)
    moves = scope.where(stage: [ Move.stages[:active], Move.stages[:inbox], Move.stages[:paused] ]).includes(campaign: :project).includes(:move_signals).to_a

    best_moves_now = moves.select do |move|
      recommendation = move.recommendation.presence || RecommendationEngine.call(move)
      BEST_LABELS.include?(recommendation) && move.active?
    end.sort_by { |move| [ -(move.ev_score || 0).to_f, move.updated_at.to_i ] }

    best_ids = best_moves_now.map(&:id).to_set

    strategic_bets = moves.select do |move|
      next false unless move.active?
      next false if best_ids.include?(move.id)

      recommendation = move.recommendation.presence || RecommendationEngine.call(move)
      (move.strategic? || move.payoff_value_normalized.to_i >= 8) && recommendation != "Probably dead"
    end.sort_by { |move| [ -(move.ev_score || 0).to_f, move.updated_at.to_i ] }

    shown_ids = best_ids + strategic_bets.map(&:id).to_set

    needs_a_call = moves.select do |move|
      next false if shown_ids.include?(move.id)

      recommendation = move.recommendation.presence || RecommendationEngine.call(move)
      flags = StalenessDetector.call(move)
      NEEDS_CALL_LABELS.include?(recommendation) || flags[:needs_signal] || flags[:reassess]
    end.sort_by { |move| [ -StalenessDetector.call(move)[:inactive_days], (move.ev_score || 0).to_f ] }

    {
      best_moves_now: best_moves_now,
      strategic_bets: strategic_bets,
      needs_a_call: needs_a_call
    }
  end
end
