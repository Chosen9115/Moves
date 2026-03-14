class RecommendationEngine
  LABELS = ["Push now", "Good bet", "Optional", "Needs signal", "Probably dead", "Reassess"].freeze

  def self.call(move)
    flags = StalenessDetector.call(move)
    ev = EvCalculator.call(move)
    probability = move.adjusted_probability || move.subjective_probability || move.base_rate
    effort = move.effort_minutes

    return "Reassess" if flags[:reassess]
    return "Needs signal" if flags[:needs_signal] && (probability.blank? || ev.blank?)
    return "Needs signal" if probability.blank?
    return "Optional" if ev.blank?

    if ev < 0.30 && probability <= 25 && effort.to_i >= 240
      return "Probably dead"
    end

    if ev >= 1.20 && probability >= 40 && effort.to_i <= 240
      return "Push now"
    end

    if ev >= 0.60 && probability >= 25
      return "Good bet"
    end

    return "Needs signal" if flags[:needs_signal]

    "Optional"
  end
end
