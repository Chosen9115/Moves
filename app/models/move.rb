class Move < ApplicationRecord
  belongs_to :campaign, optional: true
  has_many :move_signals, class_name: "MoveSignal", foreign_key: :move_id, dependent: :destroy

  enum :move_type, {
    tactical: 0,
    strategic: 1
  }, default: :tactical

  enum :stage, {
    inbox: 0,
    active: 1,
    paused: 2,
    archived: 3,
    completed: 4
  }, default: :inbox

  enum :payoff_type, {
    revenue: 0,
    leverage: 1,
    learning: 2,
    risk_reduction: 3,
    relationship: 4,
    operations: 5
  }, prefix: true

  PAYOFF_SCALE = [ 1, 2, 3, 5, 8, 13 ].freeze
  PAYOFF_TAG_OPTIONS = %w[revenue leverage learning risk_reduction relationship operations acquisition].freeze
  PROBABILITY_SCALE = [ 10, 25, 40, 60, 75, 90 ].freeze
  EFFORT_SCALE = [ 10, 30, 60, 120, 240, 480, 960 ].freeze

  validates :title, presence: true
  validates :subjective_probability, inclusion: { in: PROBABILITY_SCALE }, allow_nil: true
  validates :base_rate, inclusion: { in: PROBABILITY_SCALE }, allow_nil: true
  validates :adjusted_probability, inclusion: { in: 5..95 }, allow_nil: true
  validates :payoff_value_normalized, inclusion: { in: PAYOFF_SCALE }, allow_nil: true
  validates :effort_minutes, inclusion: { in: EFFORT_SCALE }, allow_nil: true
  validate :payoff_tags_must_be_supported

  before_validation :ensure_uuid
  before_validation :normalize_collections
  before_validation :derive_defaults
  before_save :apply_scoring
  after_commit :refresh_campaign_metrics, on: %i[create update]

  scope :active_surface, -> { where(stage: %i[inbox active paused]) }
  scope :archived_surface, -> { where(stage: %i[archived completed]) }

  def last_signal_at
    move_signals.maximum(:created_at) || updated_at || created_at
  end

  def inactive_days
    return 0 unless last_signal_at

    ((Time.current - last_signal_at) / 1.day).floor
  end

  def stale_flags
    StalenessDetector.call(self)
  end

  def recalculate_after_signal!(signal)
    self.adjusted_probability = SignalImpactEngine.call(self, signal)
    apply_scoring
    save!
  end

  def fields_ready_for_active?
    success_definition.present? && payoff_value_normalized.present? && adjusted_probability.present? && effort_minutes.present?
  end

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def normalize_collections
    self.advantages = Array(advantages).map(&:to_s).map(&:strip).reject(&:blank?)
    self.blockers = Array(blockers).map(&:to_s).map(&:strip).reject(&:blank?)
    self.payoff_tags = Array(payoff_tags).map { |value| value.to_s.strip.underscore }.reject(&:blank?).uniq
  end

  def derive_defaults
    self.adjusted_probability ||= subjective_probability || base_rate
    self.payoff_value_normalized ||= payoff_value_raw.to_i if payoff_value_raw.present?
    apply_clarify_defaults if success_definition.present?
    self.stage = :active if inbox? && fields_ready_for_active?
    self.completed_at = Time.current if completed? && completed_at.blank?
  end

  def apply_clarify_defaults
    return unless payoff_value_normalized.blank? || adjusted_probability.blank? || effort_minutes.blank?

    if strategic?
      self.payoff_value_normalized ||= 8
      self.adjusted_probability ||= 25
      self.effort_minutes ||= 120
    else
      self.payoff_value_normalized ||= 3
      self.adjusted_probability ||= 60
      self.effort_minutes ||= 30
    end
  end

  def apply_scoring
    self.ev_score = EvCalculator.call(self)
    self.recommendation = RecommendationEngine.call(self)
  end

  def refresh_campaign_metrics
    campaign&.refresh_metrics!
  end

  def payoff_tags_must_be_supported
    unsupported = payoff_tags - PAYOFF_TAG_OPTIONS
    return if unsupported.empty?

    errors.add(:payoff_tags, "contains unsupported values: #{unsupported.join(', ')}")
  end
end
