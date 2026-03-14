class EvCalculator
  def self.call(move)
    payoff = move.payoff_value_normalized
    probability = move.adjusted_probability
    effort = move.effort_minutes

    return nil if payoff.blank? || probability.blank? || effort.blank? || effort.to_i <= 0

    ((payoff.to_f * probability.to_f) / effort.to_f).round(4)
  end
end
