class Campaign < ApplicationRecord
  belongs_to :project, optional: true
  has_many :moves, dependent: :nullify

  enum :status, {
    active: 0,
    paused: 1,
    archived: 2
  }, default: :active

  validates :name, presence: true

  before_validation :ensure_uuid

  def refresh_metrics!
    active_moves = moves.where(stage: [ Move.stages[:active], Move.stages[:inbox], Move.stages[:paused] ])
    total = active_moves.where.not(ev_score: nil).sum(:ev_score)
    active_count = active_moves.where(stage: Move.stages[:active]).count
    signal_window = moves.joins(:move_signals).where(signals: { created_at: 14.days.ago..Time.current })
    positives = signal_window.where(signals: { direction: MoveSignal.directions[:positive] }).count
    negatives = signal_window.where(signals: { direction: MoveSignal.directions[:negative] }).count
    momentum = positives - negatives
    trend = if positives + negatives == 0
      0.0
    else
      momentum.to_f / (positives + negatives).to_f
    end

    update_columns(
      total_ev: total,
      active_move_count: active_count,
      momentum_score: momentum,
      confidence_trend: trend.round(4),
      updated_at: Time.current
    )
  end

  def top_next_move
    moves.where(stage: Move.stages[:active]).order(ev_score: :desc, updated_at: :asc).first
  end

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
