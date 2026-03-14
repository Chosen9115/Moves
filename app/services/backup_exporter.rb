class BackupExporter
  def self.call
    {
      exported_at: Time.current.iso8601,
      campaigns: campaigns_payload,
      moves: moves_payload,
      signals: signals_payload
    }
  end

  def self.campaigns_payload
    Campaign.order(:created_at).map do |campaign|
      {
        uuid: campaign.uuid,
        name: campaign.name,
        objective: campaign.objective,
        status: campaign.status,
        total_ev: campaign.total_ev,
        momentum_score: campaign.momentum_score,
        confidence_trend: campaign.confidence_trend,
        active_move_count: campaign.active_move_count,
        created_at: campaign.created_at,
        updated_at: campaign.updated_at
      }
    end
  end
  private_class_method :campaigns_payload

  def self.moves_payload
    Move.order(:created_at).map do |move|
      {
        uuid: move.uuid,
        title: move.title,
        description: move.description,
        campaign_uuid: move.campaign&.uuid,
        move_type: move.move_type,
        stage: move.stage,
        success_definition: move.success_definition,
        payoff_type: move.payoff_type,
        payoff_tags: move.payoff_tags,
        payoff_value_raw: move.payoff_value_raw,
        payoff_value_normalized: move.payoff_value_normalized,
        base_rate: move.base_rate,
        subjective_probability: move.subjective_probability,
        adjusted_probability: move.adjusted_probability,
        effort_minutes: move.effort_minutes,
        advantages: move.advantages,
        blockers: move.blockers,
        ev_score: move.ev_score,
        confidence_score: move.confidence_score,
        recommendation: move.recommendation,
        due_date: move.due_date,
        completed_at: move.completed_at,
        notes: move.notes,
        created_at: move.created_at,
        updated_at: move.updated_at
      }
    end
  end
  private_class_method :moves_payload

  def self.signals_payload
    MoveSignal.order(:created_at).map do |signal|
      {
        uuid: signal.uuid,
        move_uuid: signal.move.uuid,
        signal_type: signal.signal_type,
        note: signal.note,
        direction: signal.direction,
        magnitude: signal.magnitude,
        created_at: signal.created_at,
        updated_at: signal.updated_at
      }
    end
  end
  private_class_method :signals_payload
end
