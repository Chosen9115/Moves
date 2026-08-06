# frozen_string_literal: true

module Api
  module V1
    # Handles delegation lifecycle actions on a specific move.
    #
    # POST /api/v1/moves/:id/delegate             — orchestrator delegates to an agent
    # POST /api/v1/moves/:id/claim                — agent atomically claims the move
    # POST /api/v1/moves/:id/delegation/callback  — agent reports progress/outcome
    #
    # All state transitions are ATOMIC conditional UPDATEs (id + allowed current
    # states, and — for agent actions — assignee + delegation_id in the WHERE), so
    # concurrent delegate/claim/callback requests and stale (post re-delegation)
    # callbacks can't corrupt state.
    class MoveDelegationsController < BaseController
      # Scope checks run BEFORE set_move so a wrong-scope token can't probe move
      # existence (403 before 404).
      before_action :require_moves_write_scope!,      only: :delegate_action
      before_action :require_delegation_write_scope!, only: %i[claim callback]
      before_action :set_move

      DELEGATABLE_FROM = %w[none done blocked stalled].freeze
      CALLBACK_FROM    = %w[accepted in_progress].freeze
      CALLBACK_STATES  = %w[in_progress done blocked].freeze
      COMPLETABLE      = %w[inbox active paused].freeze

      # POST /api/v1/moves/:id/delegate  (scope: moves:write — orchestrator/Carlos)
      def delegate_action
        assignee = params[:assignee].to_s.strip
        return render_error(422, "invalid_argument", "assignee is required.") if assignee.blank?

        now = Time.current
        affected = Move.where(id: @move.id, delegation_state: DELEGATABLE_FROM).update_all(
          assignee:          assignee,
          delegation_state:  "delegated",
          delegation_id:     SecureRandom.urlsafe_base64(16),
          delegated_at:      now,
          delegation_result: nil,
          reported_at:       nil,
          updated_at:        now
        )

        if affected == 1
          @move.reload
          render :show, status: :ok
        else
          render_error(409, "conflict",
                       "Move is currently in-flight (state: #{@move.reload.delegation_state}). " \
                       "Cannot re-delegate until it completes.")
        end
      end

      # POST /api/v1/moves/:id/claim  (scope: delegation:write — agent)
      def claim
        now = Time.current
        # Atomic: only the worker whose UPDATE flips delegated -> accepted wins.
        affected = Move.where(
          id:               @move.id,
          assignee:         current_api_token.name,
          delegation_state: "delegated"
        ).update_all(delegation_state: "accepted", updated_at: now)

        if affected == 1
          @move.reload
          render :show, status: :ok
        else
          render_error(409, "conflict",
                       "Move could not be claimed: it is not delegated to this agent, " \
                       "or it was already claimed by another worker.")
        end
      end

      # POST /api/v1/moves/:id/delegation/callback  (scope: delegation:write — agent)
      def callback
        # Clear 403 for a move not assigned to this agent (assignee is stable).
        unless @move.assignee == current_api_token.name
          return render_error(403, "forbidden", "This move is not assigned to your token.")
        end

        status = params[:status].to_s.strip
        unless CALLBACK_STATES.include?(status)
          return render_error(422, "invalid_argument",
                              "status must be one of: #{CALLBACK_STATES.join(', ')}.")
        end

        now = Time.current
        attrs = {
          delegation_state:  status,
          delegation_result: params[:result].to_s,
          reported_at:       now, # every callback is a heartbeat — resets the stall timer
          updated_at:        now
        }

        # Atomic: only transition from a CLAIMED state (accepted/in_progress) whose
        # delegation_id matches the body. A missing claim, a stale nonce (after a
        # re-delegation), or an already-terminal move matches 0 rows -> 409.
        affected = Move.where(
          id:               @move.id,
          assignee:         current_api_token.name,
          delegation_id:    params[:delegation_id].to_s,
          delegation_state: CALLBACK_FROM
        ).update_all(attrs)

        if affected.zero?
          return render_error(409, "conflict",
                              "Callback rejected: claim the move first, the delegation_id is stale, " \
                              "or the delegation already completed.")
        end

        # done -> complete the move if it's still on an active surface.
        if status == "done"
          Move.where(id: @move.id, stage: COMPLETABLE).update_all(
            stage: "completed", completed_at: now, updated_at: now
          )
        end

        @move.reload
        render :show, status: :ok
      end

      private

      def set_move
        @move = Move.find_by(id: params[:id] || params[:move_id])
        render_error(404, "not_found", "Move not found.") unless @move
      end

      def require_moves_write_scope!
        require_scope!("moves:write")
      end

      def require_delegation_write_scope!
        require_scope!("delegation:write")
      end
    end
  end
end
