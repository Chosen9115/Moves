# ── Admin user ──────────────────────────────────────────────────────────────
# Credentials come from ENV so nothing sensitive is committed.
# Set MOVES_ADMIN_EMAIL and MOVES_ADMIN_PASSWORD before running seeds.
admin_email    = ENV.fetch("MOVES_ADMIN_EMAIL", "admin@moves.local")
admin_password = ENV["MOVES_ADMIN_PASSWORD"]

if admin_password.blank?
  puts "WARNING: MOVES_ADMIN_PASSWORD is not set — skipping admin user creation."
  puts "         Set the variable and re-run `bin/rails db:seed` to create the user."
else
  user = User.find_or_initialize_by(email_address: admin_email)
  if user.new_record?
    user.password = admin_password
    user.save!
    puts "Created admin user: #{admin_email}"
  else
    puts "Admin user already exists: #{admin_email}"
  end
end

# ── Sample data ──────────────────────────────────────────────────────────────
quick_pay = Campaign.find_or_create_by!(name: "Quick Pay Pilots") do |campaign|
  campaign.objective = "Book and launch top pilot opportunities"
end

fundraising = Campaign.find_or_create_by!(name: "Fundraising") do |campaign|
  campaign.objective = "Secure next funding conversations"
end

move = Move.find_or_initialize_by(title: "Pitch Quick Pay to ATL")
move.assign_attributes(
  campaign: quick_pay,
  move_type: :strategic,
  stage: :active,
  success_definition: "Pilot meeting booked",
  payoff_type: :leverage,
  payoff_value_normalized: 13,
  subjective_probability: 40,
  adjusted_probability: 40,
  effort_minutes: 30,
  advantages: [ "warm intro" ],
  blockers: [ "internal bandwidth" ],
  notes: "Initial seeded move"
)
move.save!

Move.find_or_create_by!(title: "Send investor follow-up") do |m|
  m.campaign = fundraising
  m.move_type = :tactical
  m.stage = :inbox
  m.success_definition = "Next call booked"
  m.payoff_type = :relationship
  m.payoff_value_normalized = 8
  m.subjective_probability = 25
  m.adjusted_probability = 25
  m.effort_minutes = 30
end

AppPreference.current
