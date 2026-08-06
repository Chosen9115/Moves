# frozen_string_literal: true

# Marks delegations that have been in-flight (delegated/accepted/in_progress)
# with no activity for more than 24 hours as "stalled".
#
# "Activity" = the later of the last callback (reported_at, set on EVERY
# callback incl. in_progress heartbeats) or the original delegated_at. So an
# agent that keeps sending in_progress pings is never swept; one that goes
# silent for 24h is. done/blocked are terminal (not in-flight) and never swept.
class DelegationTimeoutSweepJob < ApplicationJob
  queue_as :default

  IN_FLIGHT_STATES = %w[delegated accepted in_progress].freeze
  TIMEOUT = 24.hours

  def perform
    Move
      .where(delegation_state: IN_FLIGHT_STATES)
      .where("COALESCE(reported_at, delegated_at) < ?", TIMEOUT.ago)
      .update_all(delegation_state: "stalled", updated_at: Time.current)
  end
end
