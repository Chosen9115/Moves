module Api
  module V1
    class TodayController < BaseController
      before_action -> { require_scope!("moves:read") }

      def index
        classifier_moves = FocusClassifier.call.fetch(:best_moves_now)

        due_today = Move.where(stage: %i[active inbox paused])
                        .where(due_date: Date.current.all_day)
                        .to_a

        @moves = (classifier_moves + due_today).uniq(&:id)
      end
    end
  end
end
