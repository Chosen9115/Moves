class MoveSignal < ApplicationRecord
  self.table_name = "signals"

  belongs_to :move

  enum :direction, {
    positive: 0,
    negative: 1,
    neutral: 2
  }, default: :neutral

  enum :magnitude, {
    low: 0,
    medium: 1,
    high: 2
  }, default: :medium

  validates :signal_type, presence: true

  before_validation :ensure_uuid
  after_commit :recalculate_move, on: :create

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def recalculate_move
    move.recalculate_after_signal!(self)
    move.campaign&.refresh_metrics!
  end
end
