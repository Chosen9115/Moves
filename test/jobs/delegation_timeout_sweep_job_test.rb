require "test_helper"

class DelegationTimeoutSweepJobTest < ActiveSupport::TestCase
  setup do
    @move = moves(:atl_pitch)
    @move2 = moves(:cabalo_followup)
    # Reset delegation state
    @move.update_columns(delegation_state: "none", assignee: nil, delegation_id: nil,
                         delegated_at: nil, reported_at: nil)
    @move2.update_columns(delegation_state: "none", assignee: nil, delegation_id: nil,
                          delegated_at: nil, reported_at: nil)
  end

  test "marks old in-flight delegations as stalled" do
    @move.update_columns(
      delegation_state: "delegated",
      assignee:         "darwin",
      delegation_id:    "abc",
      delegated_at:     25.hours.ago,
      reported_at:      nil
    )
    @move2.update_columns(
      delegation_state: "in_progress",
      assignee:         "olympus",
      delegation_id:    "def",
      delegated_at:     25.hours.ago,
      reported_at:      nil
    )

    DelegationTimeoutSweepJob.perform_now

    assert_equal "stalled", @move.reload.delegation_state
    assert_equal "stalled", @move2.reload.delegation_state
  end

  test "does not stall a recent delegation" do
    @move.update_columns(
      delegation_state: "delegated",
      assignee:         "darwin",
      delegation_id:    "abc",
      delegated_at:     1.hour.ago,
      reported_at:      nil
    )

    DelegationTimeoutSweepJob.perform_now

    assert_equal "delegated", @move.reload.delegation_state
  end

  test "does not touch delegations with reported_at set" do
    @move.update_columns(
      delegation_state: "in_progress",
      assignee:         "darwin",
      delegation_id:    "abc",
      delegated_at:     25.hours.ago,
      reported_at:      1.hour.ago  # has a reported_at — not swept
    )

    DelegationTimeoutSweepJob.perform_now

    assert_equal "in_progress", @move.reload.delegation_state
  end

  test "does not affect non-in-flight states (done, blocked, stalled, none)" do
    %w[done blocked stalled none].each do |state|
      @move.update_columns(
        delegation_state: state,
        delegated_at:     25.hours.ago,
        reported_at:      nil
      )
      DelegationTimeoutSweepJob.perform_now
      assert_equal state, @move.reload.delegation_state, "Should not change #{state}"
    end
  end

  test "sweeps accepted state as well" do
    @move.update_columns(
      delegation_state: "accepted",
      assignee:         "darwin",
      delegation_id:    "abc",
      delegated_at:     25.hours.ago,
      reported_at:      nil
    )

    DelegationTimeoutSweepJob.perform_now

    assert_equal "stalled", @move.reload.delegation_state
  end
end
