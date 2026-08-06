# frozen_string_literal: true

module Api
  module V1
    # Handles delegation lifecycle actions on a specific move.
    #
    # POST /api/v1/moves/:id/delegate             — orchestrator delegates to an agent
    # POST /api/v1/moves/:id/claim                — agent atomically claims the move
    # POST /api/v1/moves/:id/delegation/callback  — agent reports progress/outcome
    class MoveDelegationsController < BaseController
      before_action :set_move
      before_action :require_moves_write_scope!,      only: :delegate_action
      before_action :require_delegation_write_scope!, only: %i[claim callback]

      # POST /api/v1/moves/:id/delegate
      # Scope: moves:write (orchestrator / Carlos)
      def delegate_action
        assignee = params[:assignee].to_s.strip
        if assignee.blank?
          return render_error(422, "invalid_argument", "assignee is required.")
        end

        if @move.delegation_in_flight?
          return render_error(409, "conflict",
                              "Move is currently in-flight (state: #{@move.delegation_state}). " \
                              "Cannot re-delegate until the current delegation completes.")
        end

        @move.update!(
          assignee:          assignee,
          delegation_state:  "delegated",
          delegation_id:     SecureRandom.urlsafe_base64(16),
          delegated_at:      Time.current,
          delegation_result: nil,
          reported_at:       nil
        )

        render :show, status: :ok
      end

      # POST /api/v1/moves/:id/claim
      # Scope: delegation:write (agent)
      def claim
        # Atomic claim: update only if still delegated and assigned to this agent.
        # Returns affected row count — 0 means already claimed, not yours, or not delegated.
        affected = Move.where(
          id:               @move.id,
          assignee:         current_api_token.name,
          delegation_state: "delegated"
        ).update_all(delegation_state: "accepted")

        if affected == 1
          @move.reload
          render :show, status: :ok
        else
          render_error(409, "conflict",
                       "Move could not be claimed: it is not delegated to this agent, " \
                       "or it was already claimed by another worker.")
        end
      end

      # POST /api/v1/moves/:id/delegation/callback
      # Scope: delegation:write (agent)
      def callback
        # Verify this move belongs to the calling agent.
        unless @move.assignee == current_api_token.name
          return render_error(403, "forbidden",
                              "This move is not assigned to your token.")
        end

        body_delegation_id = params[:delegation_id].to_s.strip
        status             = params[:status].to_s.strip
        result             = params[:result].to_s

        # Reject stale/wrong delegation_id.
        unless @move.delegation_id.present? && @move.delegation_id == body_delegation_id
          return render_error(409, "conflict",
                              "delegation_id does not match. The callback is stale or for a prior delegation.")
        end

        allowed_statuses = %w[in_progress done blocked]
        unless allowed_statuses.include?(status)
          return render_error(422, "invalid_argument",
                              "status must be one of: #{allowed_statuses.join(', ')}.")
        end

        attrs = { delegation_state: status, delegation_result: result }

        # Set reported_at for terminal/blocking states.
        attrs[:reported_at] = Time.current if %w[done blocked].include?(status)

        # On done, complete the move if it's still in an active surface stage.
        if status == "done" && @move.stage.in?(%w[inbox active paused])
          attrs[:stage]        = "completed"
          attrs[:completed_at] = Time.current
        end

        @move.update!(attrs)

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
