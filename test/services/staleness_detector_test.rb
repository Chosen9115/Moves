require "test_helper"

class StalenessDetectorTest < ActiveSupport::TestCase
  test "marks move as needs signal after 10 days" do
    move = Move.create!(title: "Old move", stage: :active)
    move.update_column(:updated_at, 11.days.ago)

    flags = StalenessDetector.call(move)

    assert flags[:needs_signal]
    assert_not flags[:reassess]
  end

  test "marks reassess after repeated negative signals" do
    move = moves(:cabalo_followup)
    move.move_signals.create!(signal_type: "No budget", direction: :negative, magnitude: :medium)
    move.move_signals.create!(signal_type: "No owner", direction: :negative, magnitude: :medium)

    flags = StalenessDetector.call(move)

    assert flags[:reassess]
    assert flags[:repeated_negative_signals]
  end
end
