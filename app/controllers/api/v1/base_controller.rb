module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_token!

      attr_reader :current_api_token

      private

      def authenticate_api_token!
        raw = bearer_token
        unless raw
          render_error(401, "unauthorized", "Missing or malformed Authorization header.")
          return
        end

        @current_api_token = ApiToken.authenticate(raw)
        unless @current_api_token
          render_error(401, "unauthorized", "Invalid or revoked token.")
        end
      end

      def require_scope!(scope)
        return if current_api_token&.has_scope?(scope)

        render_error(403, "forbidden", "Token lacks required scope: #{scope}.")
      end

      def bearer_token
        header = request.headers["Authorization"]
        return nil unless header&.start_with?("Bearer ")

        header.delete_prefix("Bearer ").strip.presence
      end

      def render_error(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end
