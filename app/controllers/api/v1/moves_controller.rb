module Api
  module V1
    class MovesController < BaseController
      before_action :require_read_scope!, only: %i[index show]
      before_action :require_write_scope!, only: %i[create update]
      before_action :set_move, only: %i[show update]

      MAX_PAGE = 10_000

      def index
        page = [ [ params.fetch(:page, 1).to_i, 1 ].max, MAX_PAGE ].min
        per  = [ [ params.fetch(:per, 50).to_i, 1 ].max, 100 ].min

        total  = Move.count
        @moves = Move.order(created_at: :desc).offset((page - 1) * per).limit(per)
        @meta  = { page: page, per: per, total: total }
      end

      def show; end

      def create
        @move = Move.new(move_params)
        if @move.save
          render :show, status: :created
        else
          render_validation_errors(@move)
        end
      end

      def update
        if @move.update(move_params)
          render :show, status: :ok
        else
          render_validation_errors(@move)
        end
      end

      private

      def set_move
        @move = Move.find_by(id: params[:id])
        render_error(404, "not_found", "Move not found.") unless @move
      end

      # NOTE: :stage is intentionally NOT permitted — lifecycle transitions
      # (active/paused/archived/completed) have dedicated semantics (e.g.
      # completed_at) and must not be set by a blanket write. Expose explicit
      # transition endpoints in a later phase if agents need them.
      def move_params
        params.require(:move).permit(
          :title, :description, :success_definition, :due_date,
          :effort_minutes, :subjective_probability, :payoff_value_normalized,
          :payoff_type, :move_type
        )
      end

      def require_read_scope!
        require_scope!("moves:read")
      end

      def require_write_scope!
        require_scope!("moves:write")
      end

      def render_validation_errors(record)
        render json: {
          error: {
            code: "validation_failed",
            message: "Validation failed.",
            details: record.errors.full_messages
          }
        }, status: :unprocessable_entity
      end
    end
  end
end
