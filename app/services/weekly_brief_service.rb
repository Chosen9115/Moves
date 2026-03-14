class WeeklyBriefService
  def self.call
    new.generate
  end

  def generate
    completed_last_week = Move.where(stage: :completed)
                              .where(completed_at: 7.days.ago..Time.current)
                              .count

    active_moves = Move.where(stage: %i[active inbox paused]).includes(:campaign, :move_signals)

    top_move = active_moves
      .select { |m| m.recommendation.present? }
      .min_by { |m| [rec_priority(m.recommendation), -(m.ev_score || 0)] }

    most_neglected_move = active_moves
      .select { |m| m.last_signal_at.present? }
      .max_by { |m| (Time.current - m.last_signal_at) / 1.day }

    neglect_days = most_neglected_move ? ((Time.current - most_neglected_move.last_signal_at) / 1.day).floor : 0

    campaigns_with_moves = Campaign.joins(:moves).where(moves: { stage: %i[active inbox paused] }).distinct
    total_pipeline = Move.where(stage: %i[active inbox paused]).sum { |m| m.payoff_value_raw.to_f }

    # Project-level neglect
    overdue_projects = Project.all.select(&:overdue?).sort_by { |p| -(p.days_since_last_signal || 0) }

    {
      completed_last_week: completed_last_week,
      top_move: top_move,
      most_neglected_move: most_neglected_move,
      neglect_days: neglect_days,
      total_pipeline: total_pipeline,
      active_move_count: active_moves.count,
      overdue_projects: overdue_projects
    }
  end

  private

  def rec_priority(label)
    { "Push now" => 0, "Reassess" => 1, "Good bet" => 2, "Needs signal" => 3, "Optional" => 4, "Probably dead" => 5 }[label] || 6
  end
end
