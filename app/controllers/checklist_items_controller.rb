class ChecklistItemsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_move
  before_action :set_checklist_item, only: %i[update destroy]

  def create
    @checklist_item = @move.checklist_items.build(checklist_item_params)

    if @checklist_item.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("checklist-list", partial: "moves/checklist_item",
                                                  locals: { checklist_item: @checklist_item, move: @move }),
            turbo_stream.replace("checklist-empty", html: "")
          ]
        end
        format.html { redirect_to move_path(@move), notice: "Item added." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          # Prepend the error without destroying the existing list/form.
          message = ERB::Util.html_escape(@checklist_item.errors.full_messages.to_sentence)
          render turbo_stream: turbo_stream.prepend(
            "checklist-list",
            html: "<p style='color:var(--danger); font-size:12px;'>#{message}</p>"
          )
        end
        format.html { redirect_to move_path(@move), alert: @checklist_item.errors.full_messages.to_sentence }
      end
    end
  end

  def update
    if @checklist_item.update(checklist_item_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@checklist_item),
            partial: "moves/checklist_item",
            locals: { checklist_item: @checklist_item, move: @move }
          )
        end
        format.html { redirect_to move_path(@move), notice: "Item updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@checklist_item),
            partial: "moves/checklist_item",
            locals: { checklist_item: @checklist_item, move: @move }
          )
        end
        format.html { redirect_to move_path(@move), alert: @checklist_item.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @checklist_item.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(dom_id(@checklist_item))
      end
      format.html { redirect_to move_path(@move), notice: "Item deleted." }
    end
  end

  private

  def set_move
    @move = Move.find(params[:move_id])
  end

  def set_checklist_item
    @checklist_item = @move.checklist_items.find(params[:id])
  end

  # :position is auto-assigned server-side (no client reordering endpoint yet).
  def checklist_item_params
    params.require(:checklist_item).permit(:title, :done)
  end
end
