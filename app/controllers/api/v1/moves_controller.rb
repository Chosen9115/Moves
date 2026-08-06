module Api
  module V1
    class MovesController < BaseController
      before_action :require_read_scope!, only: %i[index show]
      before_action :require_write_scope!, only: %i[create update]
      before_action :set_move, only: %i[show update]

      def index
        page = [ params.fetch(:page, 1).to_i, 1 ].max
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

      def move_params
        params.require(:move).permit(
          :title, :description, :success_definition, :due_date,
          :effort_minutes, :subjective_probability, :payoff_value_normalized,
          :payoff_type, :move_type, :stage
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
