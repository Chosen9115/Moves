module Api
  module V1
    class ChecklistItemsController < BaseController
      before_action :require_read_scope!,  only: :index
      before_action :require_write_scope!, only: %i[create update destroy]
      before_action :set_move
      before_action :set_checklist_item, only: %i[update destroy]

      # GET /api/v1/moves/:move_id/checklist_items
      def index
        @checklist_items = @move.checklist_items
      end

      # POST /api/v1/moves/:move_id/checklist_items
      def create
        @checklist_item = @move.checklist_items.build(checklist_item_params)

        if @checklist_item.save
          render :show, status: :created
        else
          render_validation_errors(@checklist_item)
        end
      end

      # PATCH /api/v1/moves/:move_id/checklist_items/:id
      def update
        if @checklist_item.update(checklist_item_params)
          render :show
        else
          render_validation_errors(@checklist_item)
        end
      end

      # DELETE /api/v1/moves/:move_id/checklist_items/:id
      def destroy
        @checklist_item.destroy
        head :no_content
      end

      private

      def set_move
        @move = Move.find_by(id: params[:move_id])
        render_error(404, "not_found", "Move not found.") unless @move
      end

      def set_checklist_item
        @checklist_item = @move.checklist_items.find_by(id: params[:id])
        render_error(404, "not_found", "ChecklistItem not found.") unless @checklist_item
      end

      def checklist_item_params
        params.require(:checklist_item).permit(:title, :done, :position)
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
