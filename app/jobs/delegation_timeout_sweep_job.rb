# frozen_string_literal: true

# Marks delegations that have been in-flight (delegated/accepted/in_progress)
# for more than 24 hours without a callback as "stalled".
#
# Only moves where reported_at IS NULL are swept — a move with a recent
# in_progress ping (which does NOT set reported_at) can still be swept if
# delegated_at is old enough; an agent should re-delegate or the orchestrator
# should intervene.
class DelegationTimeoutSweepJob < ApplicationJob
  queue_as :default

  IN_FLIGHT_STATES = %w[delegated accepted in_progress].freeze
  TIMEOUT = 24.hours

  def perform
    Move
      .where(delegation_state: IN_FLIGHT_STATES)
      .where(reported_at: nil)
      .where(Move.arel_table[:delegated_at].lt(TIMEOUT.ago))
      .update_all(delegation_state: "stalled")
  end
end
