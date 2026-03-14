class SignalImpactEngine
  DELTA_MAP = {
    "positive" => { "low" => 5, "medium" => 10, "high" => 20 },
    "negative" => { "low" => -5, "medium" => -10, "high" => -20 },
    "neutral" => { "low" => 0, "medium" => 0, "high" => 0 }
  }.freeze

  def self.call(move, signal)
    base_probability = move.adjusted_probability || move.subjective_probability || move.base_rate || 25
    delta = DELTA_MAP.fetch(signal.direction, DELTA_MAP["neutral"]).fetch(signal.magnitude, 0)
    [ [ base_probability + delta, 95 ].min, 5 ].max
  end
end
