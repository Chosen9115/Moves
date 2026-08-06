namespace :moves do
  namespace :delegation do
    desc "Sweep stalled delegations: mark in-flight moves older than 24h as stalled"
    task sweep: :environment do
      DelegationTimeoutSweepJob.perform_now
      puts "Delegation timeout sweep complete."
    end
  end
end
