class AiSuggestionProvider
  def self.enabled?
    AppPreference.current.ai_enabled_for_openai?
  end

  def self.suggest_move(move)
    return {} unless enabled?

    provider.suggest_move(move)
  rescue StandardError => e
    Rails.logger.warn("AI suggest_move failed: #{e.message}")
    {}
  end

  def self.signal_summary(move)
    return nil unless enabled?

    provider.signal_summary(move)
  rescue StandardError => e
    Rails.logger.warn("AI signal_summary failed: #{e.message}")
    nil
  end

  def self.probability_hint(move)
    return nil unless enabled?

    provider.probability_hint(move)
  rescue StandardError => e
    Rails.logger.warn("AI probability_hint failed: #{e.message}")
    nil
  end

  def self.parse_text(text)
    return {} unless enabled?

    provider.parse_text(text)
  rescue StandardError => e
    Rails.logger.warn("AI parse_text failed: #{e.message}")
    {}
  end

  def self.provider
    Ai::Providers::OpenAiProvider.new(AppPreference.current)
  end
  private_class_method :provider
end
