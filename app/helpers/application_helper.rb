module ApplicationHelper
  # Display labels (voiced, human) → internal labels (stored in DB)
  REC_DISPLAY = {
    "Push now"      => "Move now",
    "Good bet"      => "Strong position",
    "Needs signal"  => "Gone quiet",
    "Optional"      => "Low priority",
    "Probably dead" => "Let it go",
    "Reassess"      => "Re-examine"
  }.freeze

  REC_BADGE = {
    "Push now"      => "badge-green",
    "Good bet"      => "badge-blue",
    "Needs signal"  => "badge-amber",
    "Optional"      => "badge-gray",
    "Probably dead" => "badge-red",
    "Reassess"      => "badge-red"
  }.freeze

  def rec_display(label)
    REC_DISPLAY[label] || label
  end

  def rec_badge_class(label)
    REC_BADGE[label] || "badge-gray"
  end
end
