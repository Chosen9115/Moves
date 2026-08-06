# frozen_string_literal: true

module Api
  module V1
    # Handles the agent's polling queue: GET /api/v1/delegations
    class DelegationsController < BaseController
      before_action :require_delegation_read_scope!

      POLL_LIMIT = 50

      # GET /api/v1/delegations?state=delegated
      def index
        state = params.fetch(:state, "delegated").to_s
        unless Move::DELEGATION_STATES.include?(state)
          return render_error(422, "invalid_argument",
                              "state must be one of: #{Move::DELEGATION_STATES.join(', ')}.")
        end

        @moves = Move
          .where(assignee: current_api_token.name, delegation_state: state)
          .order(delegated_at: :asc)
          .limit(POLL_LIMIT)
      end

      private

      def require_delegation_read_scope!
        require_scope!("delegation:read")
      end
    end
  end
end
