class SignalsController < ApplicationController
  def create
    @move = Move.find(params[:move_id])
    @signal = @move.move_signals.new(signal_params)

    if @signal.save
      redirect_to move_path(@move), notice: "Signal logged and move recalculated."
    else
      redirect_to move_path(@move), alert: @signal.errors.full_messages.to_sentence
    end
  end

  private

  def signal_params
    params.require(:move_signal).permit(:signal_type, :direction, :magnitude, :note)
  end
end
