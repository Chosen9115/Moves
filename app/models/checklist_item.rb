class ChecklistItem < ApplicationRecord
  belongs_to :move

  validates :title, presence: true, length: { maximum: 500 }
  # Guards every write path — including backup import, which bypasses controller
  # strong params — against negative/non-integer positions.
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :ensure_uuid
  before_create :assign_position

  default_scope { order(:position, :id) }

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def assign_position
    return if position.present?

    max = move.checklist_items.unscoped.where(move: move).maximum(:position) || 0
    self.position = max + 1
  end
end
