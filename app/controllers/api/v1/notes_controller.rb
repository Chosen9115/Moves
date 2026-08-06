module Api
  module V1
    class NotesController < BaseController
      before_action :require_read_scope!,  only: %i[index search]
      before_action :require_write_scope!, only: :create
      before_action :set_move,             only: %i[index create]

      # GET /api/v1/moves/:move_id/notes
      def index
        @notes = @move.notes.order(created_at: :desc)
      end

      # POST /api/v1/moves/:move_id/notes
      def create
        @note = @move.notes.build(note_params)

        if @note.save
          render :show, status: :created
        else
          render_validation_errors(@note)
        end
      end

      # GET /api/v1/notes/search?q=...
      def search
        query = params[:q].to_s.strip
        limit = [ [ params.fetch(:limit, 10).to_i, 1 ].max, 50 ].min

        metis_results = MetisClient.search(query: query, limit: limit)
        local_notes   = Note.where("body LIKE ?", "%#{query}%").order(created_at: :desc).limit(limit)

        # Merge: build a unified list, deduplicating by uuid where possible
        merged = merge_results(metis_results, local_notes)

        source_arms = []
        source_arms << "metis" if metis_results.any?
        source_arms << "local"

        render json: {
          notes:  merged,
          source: source_arms.join("+"),
          query:  query
        }
      end

      private

      def set_move
        @move = Move.find_by(id: params[:move_id])
        render_error(404, "not_found", "Move not found.") unless @move
      end

      def note_params
        params.require(:note).permit(:body, :kind, :source)
      end

      def require_read_scope!
        require_scope!("notes:read")
      end

      def require_write_scope!
        require_scope!("notes:write")
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

      def merge_results(metis_results, local_notes)
        local_data = local_notes.map { |n| note_as_json(n) }
        return local_data if metis_results.blank?

        # Try to deduplicate by uuid; Metis results come first
        metis_uuids = metis_results.filter_map { |r| r["uuid"] || r[:uuid] }.to_set
        local_only  = local_data.reject { |n| metis_uuids.include?(n[:uuid]) }
        metis_results + local_only
      end

      def note_as_json(note)
        {
          uuid:            note.uuid,
          move_id:         note.move_id,
          body:            note.body,
          kind:            note.kind,
          source:          note.source,
          metis_slug:      note.metis_slug,
          metis_synced_at: note.metis_synced_at,
          created_at:      note.created_at,
          updated_at:      note.updated_at
        }
      end
    end
  end
end
