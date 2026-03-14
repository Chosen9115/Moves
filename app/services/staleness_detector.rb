class StalenessDetector
  NEEDS_SIGNAL_DAYS = 10
  REASSESS_DAYS = 21

  def self.call(move)
    reference_time = move.last_signal_at || move.updated_at || move.created_at
    return {
      needs_signal: false,
      reassess: false,
      inactive_days: 0,
      repeated_negative_signals: false
    } if reference_time.nil?

    inactive_days = ((Time.current - reference_time) / 1.day).floor
    recent_negative_count = move.move_signals.where(direction: MoveSignal.directions[:negative])
      .where(created_at: REASSESS_DAYS.days.ago..Time.current)
      .count

    {
      needs_signal: inactive_days >= NEEDS_SIGNAL_DAYS,
      reassess: inactive_days >= REASSESS_DAYS || recent_negative_count >= 2,
      inactive_days: inactive_days,
      repeated_negative_signals: recent_negative_count >= 2
    }
  end
end
