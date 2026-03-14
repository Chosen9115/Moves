class Project < ApplicationRecord
  has_many :campaigns, dependent: :nullify
  has_many :moves, through: :campaigns

  enum :cadence, { daily: 0, weekly: 1, monthly: 2 }

  validates :name, presence: true
  validates :color, presence: true

  before_create :generate_uuid

  COLORS = %w[#1E5C42 #8B6020 #8B3A38 #1E3A5F #6B4C9A].freeze

  def last_signal_at
    moves.joins(:move_signals)
         .maximum("signals.created_at")
  end

  def days_since_last_signal
    last = last_signal_at
    return nil unless last
    (Date.today - last.to_date).to_i
  end

  def cadence_days
    case cadence
    when "daily" then 1
    when "weekly" then 7
    when "monthly" then 30
    end
  end

  def overdue?
    days = days_since_last_signal
    return false unless days
    days > cadence_days
  end

  def health
    days = days_since_last_signal
    return "green" unless days
    return "green" if days <= cadence_days
    return "amber" if days <= cadence_days * 2
    "red"
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
