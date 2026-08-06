class Note < ApplicationRecord
  belongs_to :move, optional: true

  VALID_KINDS   = %w[note prompt].freeze
  VALID_SOURCES = %w[carlos agent olympus darwin].freeze

  validates :body,   presence: true
  validates :kind,   inclusion: { in: VALID_KINDS }
  validates :source, inclusion: { in: VALID_SOURCES }

  before_validation :ensure_uuid

  # Prompts are NOT synced to durable memory — only plain notes are.
  scope :syncable, -> { where(kind: "note") }

  # Enqueue Metis sync after every create/update of a syncable note,
  # unless only metis_synced_at changed (to avoid re-enqueue loops).
  after_commit :maybe_enqueue_metis_sync, on: %i[create update]

  def project
    move&.campaign&.project
  end

  def metis_slug
    self[:metis_slug].presence || "projects/moves-notes/#{uuid}"
  end

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def maybe_enqueue_metis_sync
    return unless kind == "note"

    # Don't re-enqueue if only metis_synced_at was touched (update_columns path).
    changed_cols = previous_changes.keys.map(&:to_s)
    return if changed_cols == %w[metis_synced_at] ||
              changed_cols == %w[metis_synced_at updated_at] ||
              changed_cols == %w[metis_slug metis_synced_at] ||
              changed_cols == %w[metis_slug metis_synced_at updated_at]

    MetisSyncJob.perform_later(id)
  end
end
