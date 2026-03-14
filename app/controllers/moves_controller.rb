class MovesController < ApplicationController
  before_action :set_move, only: %i[
    show edit update destroy activate pause archive complete reassess suggest_ai signal_summary probability_hint
  ]

  def index
    @selected_campaign_id = params[:campaign_id]
    @selected_stage = params[:stage]

    scope = scoped_moves.includes(:campaign).order(updated_at: :desc)
    scope = scope.where(campaign_id: @selected_campaign_id) if @selected_campaign_id.present?

    @moves = if @selected_stage.present?
      scope.where(stage: @selected_stage)
    else
      scope.where(stage: %i[active inbox paused])
    end

    @campaigns = scoped_campaigns.order(:name)
  end

  def show
    @signal = MoveSignal.new
  end

  def new
    @move = Move.new(stage: :inbox)
  end

  def parse
    @placeholder_text = "I need to follow up with Maria at Cabalo about the pilot program. " \
      "She seemed interested when we met last week but wanted to check with her team first. " \
      "This could be worth around $50k if it lands. I'd say 60% chance. " \
      "Should probably reach out by Friday. It's part of the Quick Pay rollout."
  end

  def parse_submit
    text = params[:raw_text].to_s.strip
    if text.blank?
      redirect_to parse_moves_path, alert: "Please paste some text to parse."
      return
    end

    @parsed = AiSuggestionProvider.parse_text(text)
    if @parsed.blank?
      redirect_to parse_moves_path, alert: "AI parsing unavailable. Check settings and OPENAI_API_KEY."
      return
    end

    @raw_text = text
    @move = Move.new(
      title: @parsed["title"],
      success_definition: @parsed["success_definition"],
      payoff_value_raw: @parsed["payoff_value_raw"],
      payoff_value_normalized: @parsed["payoff_value_normalized"],
      subjective_probability: @parsed["subjective_probability"],
      effort_minutes: @parsed["effort_minutes"],
      due_date: @parsed["due_date"],
      notes: @parsed["notes"],
      stage: :inbox
    )
    @campaign_name = @parsed["campaign_name"]
    @understood = @parsed["understood"] || []
    @missing = @parsed["missing"] || []

    render :parse_confirm
  end

  def create
    attrs = move_params
    campaign_name = attrs.delete(:campaign_name)
    @move = Move.new(attrs)
    assign_campaign_from_name(@move, campaign_name)
    @move.stage = :inbox if @move.stage.blank?

    if @move.save
      redirect_target = params[:redirect_to].presence || inbox_path
      redirect_to redirect_target, notice: "Move captured."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = move_params
    campaign_name = attrs.delete(:campaign_name)
    assign_campaign_from_name(@move, campaign_name)

    if @move.update(attrs)
      redirect_to move_path(@move), notice: "Move updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @move.destroy
    redirect_to moves_path, notice: "Move deleted."
  end

  def activate
    transition_stage!(:active, "Move activated.")
  end

  def pause
    transition_stage!(:paused, "Move paused.")
  end

  def archive
    transition_stage!(:archived, "Move archived.")
  end

  def complete
    @move.update(stage: :completed, completed_at: Time.current)
    redirect_to move_path(@move), notice: "Move marked complete."
  end

  def reassess
    @move.update(recommendation: "Reassess")
    redirect_to move_path(@move), notice: "Reassessment flag applied."
  end

  def suggest_ai
    suggestions = AiSuggestionProvider.suggest_move(@move)

    if suggestions.blank?
      redirect_to edit_move_path(@move), alert: "AI suggestion unavailable. Check settings and OPENAI_API_KEY."
      return
    end

    apply_ai_suggestions(suggestions)
    @move.save!

    redirect_to edit_move_path(@move), notice: "AI suggestions applied."
  end

  def signal_summary
    summary = AiSuggestionProvider.signal_summary(@move)
    redirect_to move_path(@move), notice: summary.presence || "AI summary unavailable."
  end

  def probability_hint
    hint = AiSuggestionProvider.probability_hint(@move)

    if hint.blank?
      redirect_to move_path(@move), alert: "AI probability hint unavailable."
      return
    end

    suggested = hint[:suggested_probability].to_i
    reason = hint[:reason]
    redirect_to move_path(@move), notice: "AI probability hint: #{suggested}% - #{reason}"
  end

  private

  def set_move
    @move = Move.find(params[:id])
  end

  def move_params
    permitted = params.require(:move).permit(
      :title,
      :description,
      :campaign_id,
      :move_type,
      :stage,
      :success_definition,
      :payoff_type,
      :campaign_name,
      :payoff_tags_string,
      :payoff_value_raw,
      :payoff_value_normalized,
      :base_rate,
      :subjective_probability,
      :adjusted_probability,
      :effort_minutes,
      :due_date,
      :notes,
      :advantages_string,
      :blockers_string,
      advantages: [],
      blockers: []
    )

    attrs = permitted.except(:advantages_string, :blockers_string, :payoff_tags_string)
    attrs[:advantages] = parse_csv_list(permitted[:advantages_string]) if permitted[:advantages_string].present?
    attrs[:blockers] = parse_csv_list(permitted[:blockers_string]) if permitted[:blockers_string].present?
    attrs[:payoff_tags] = parse_csv_list(permitted[:payoff_tags_string]).map(&:underscore) if permitted[:payoff_tags_string].present?
    attrs[:advantages] ||= []
    attrs[:blockers] ||= []
    attrs[:payoff_tags] ||= []
    attrs
  end

  def transition_stage!(target_stage, message)
    @move.update(stage: target_stage)
    redirect_to request.referer.presence || move_path(@move), notice: message
  end

  def apply_ai_suggestions(suggestions)
    if suggestions[:campaign_name].present? && @move.campaign.blank?
      @move.campaign = Campaign.find_or_create_by!(name: suggestions[:campaign_name].strip)
    end

    @move.success_definition = suggestions[:success_definition] if @move.success_definition.blank? && suggestions[:success_definition].present?

    if @move.payoff_type.blank? && suggestions[:payoff_type].present? && Move.payoff_types.key?(suggestions[:payoff_type])
      @move.payoff_type = suggestions[:payoff_type]
    end

    if @move.base_rate.blank? && Move::PROBABILITY_SCALE.include?(suggestions[:base_rate].to_i)
      @move.base_rate = suggestions[:base_rate].to_i
      @move.adjusted_probability ||= @move.base_rate
    end

    return unless suggestions[:notes].present?

    existing_notes = @move.notes.to_s
    @move.notes = [existing_notes, "AI note: #{suggestions[:notes]}"].reject(&:blank?).join("\n\n")
  end

  def parse_csv_list(value)
    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def assign_campaign_from_name(move, campaign_name)
    return if campaign_name.blank?

    move.campaign = Campaign.find_or_create_by!(name: campaign_name.strip)
  end
end
