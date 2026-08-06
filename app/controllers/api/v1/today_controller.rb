module Api
  module V1
    class TodayController < BaseController
      before_action -> { require_scope!("moves:read") }

      MAX_RESULTS = 200

      def index
        classifier_moves = FocusClassifier.call.fetch(:best_moves_now)

        # Day boundary follows Time.zone (set MOVES_TIME_ZONE; see config/application.rb).
        due_today = Move.where(stage: %i[active inbox paused])
                        .where(due_date: Time.zone.today.all_day)
                        .limit(MAX_RESULTS)
                        .to_a

        @moves = (classifier_moves + due_today).uniq(&:id).first(MAX_RESULTS)
      end
    end
  end
end
