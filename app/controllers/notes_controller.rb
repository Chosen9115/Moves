class NotesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_move
  before_action :set_note, only: :destroy

  def create
    @note = @move.notes.build(note_params.merge(source: "carlos", kind: "note"))

    if @note.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("notes-list", partial: "moves/note",
                                               locals: { note: @note, move: @move }),
            turbo_stream.replace("notes-empty", html: "")
          ]
        end
        format.html { redirect_to move_path(@move), notice: "Note added." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "notes-section",
            html: "<p style='color:var(--danger);'>#{@note.errors.full_messages.to_sentence}</p>"
          )
        end
        format.html { redirect_to move_path(@move), alert: @note.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @note.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(dom_id(@note))
      end
      format.html { redirect_to move_path(@move), notice: "Note deleted." }
    end
  end

  private

  def set_move
    @move = Move.find(params[:move_id])
  end

  def set_note
    @note = @move.notes.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:body)
  end
end
