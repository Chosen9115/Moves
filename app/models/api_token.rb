class ApiToken < ApplicationRecord
  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :scopes, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def self.generate!(name:, scopes:)
    raw = SecureRandom.urlsafe_base64(32)
    digest = Digest::SHA256.hexdigest(raw)
    record = create!(name: name, token_digest: digest, scopes: scopes)
    [ record, raw ]
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    digest = Digest::SHA256.hexdigest(raw)
    token = active.find_by(token_digest: digest)
    token&.record_usage
    token
  end

  # How stale last_used_at may get before we bother writing it again. Throttling
  # avoids a DB write (and SQLite write contention) on every authenticated request.
  USAGE_TOUCH_INTERVAL = 10.minutes

  # Best-effort usage telemetry — never let a failed/contended write turn a valid
  # request into a 500.
  def record_usage
    return if last_used_at && last_used_at > USAGE_TOUCH_INTERVAL.ago

    touch(:last_used_at)
  rescue ActiveRecord::ActiveRecordError
    nil
  end

  def has_scope?(scope)
    scopes.split.include?(scope)
  end

  def active?
    revoked_at.nil?
  end

  def revoked?
    !active?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
