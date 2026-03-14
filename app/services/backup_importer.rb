require "json"

class BackupImporter
  class ImportError < StandardError; end

  def self.call(file_contents)
    payload = JSON.parse(file_contents)
    validate_payload!(payload)

    ActiveRecord::Base.transaction do
      campaign_map = upsert_campaigns(payload.fetch("campaigns"))
      move_map = upsert_moves(payload.fetch("moves"), campaign_map)
      upsert_signals(payload.fetch("signals"), move_map)
    end
  rescue JSON::ParserError
    raise ImportError, "Invalid JSON backup file"
  end

  def self.validate_payload!(payload)
    required = %w[campaigns moves signals]
    missing = required.reject { |key| payload.key?(key) }
    return if missing.empty?

    raise ImportError, "Missing keys: #{missing.join(', ')}"
  end
  private_class_method :validate_payload!

  def self.upsert_campaigns(records)
    records.each_with_object({}) do |attrs, map|
      campaign = Campaign.find_or_initialize_by(uuid: attrs.fetch("uuid"))
      campaign.assign_attributes(
        name: attrs["name"],
        objective: attrs["objective"],
        status: attrs["status"],
        total_ev: attrs["total_ev"],
        momentum_score: attrs["momentum_score"],
        confidence_trend: attrs["confidence_trend"],
        active_move_count: attrs["active_move_count"],
        created_at: attrs["created_at"],
        updated_at: attrs["updated_at"]
      )
      campaign.save!
      map[campaign.uuid] = campaign.id
    end
  end
  private_class_method :upsert_campaigns

  def self.upsert_moves(records, campaign_map)
    records.each_with_object({}) do |attrs, map|
      campaign_id = attrs["campaign_uuid"].present? ? campaign_map[attrs["campaign_uuid"]] : nil
      move = Move.find_or_initialize_by(uuid: attrs.fetch("uuid"))
      move.assign_attributes(
        title: attrs["title"],
        description: attrs["description"],
        campaign_id: campaign_id,
        move_type: attrs["move_type"],
        stage: attrs["stage"],
        success_definition: attrs["success_definition"],
        payoff_type: attrs["payoff_type"],
        payoff_tags: attrs["payoff_tags"],
        payoff_value_raw: attrs["payoff_value_raw"],
        payoff_value_normalized: attrs["payoff_value_normalized"],
        base_rate: attrs["base_rate"],
        subjective_probability: attrs["subjective_probability"],
        adjusted_probability: attrs["adjusted_probability"],
        effort_minutes: attrs["effort_minutes"],
        advantages: attrs["advantages"],
        blockers: attrs["blockers"],
        ev_score: attrs["ev_score"],
        confidence_score: attrs["confidence_score"],
        recommendation: attrs["recommendation"],
        due_date: attrs["due_date"],
        completed_at: attrs["completed_at"],
        notes: attrs["notes"],
        created_at: attrs["created_at"],
        updated_at: attrs["updated_at"]
      )
      move.save!
      map[move.uuid] = move.id
    end
  end
  private_class_method :upsert_moves

  def self.upsert_signals(records, move_map)
    records.each do |attrs|
      move_id = move_map.fetch(attrs.fetch("move_uuid"))
      signal = MoveSignal.find_or_initialize_by(uuid: attrs.fetch("uuid"))
      signal.assign_attributes(
        move_id: move_id,
        signal_type: attrs["signal_type"],
        note: attrs["note"],
        direction: attrs["direction"],
        magnitude: attrs["magnitude"],
        created_at: attrs["created_at"],
        updated_at: attrs["updated_at"]
      )
      signal.save!
    end
  end
  private_class_method :upsert_signals
end
