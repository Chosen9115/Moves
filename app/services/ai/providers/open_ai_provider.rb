require "json"
require "net/http"

module Ai
  module Providers
    class OpenAiProvider
      OPENAI_ENDPOINT = URI("https://api.openai.com/v1/responses")

      def initialize(preference)
        @preference = preference
        @api_key = preference.openai_api_key.presence || ENV["OPENAI_API_KEY"]
      end

      def suggest_move(move)
        response = request_json!(<<~PROMPT)
          You are helping classify a task called a move.
          Return strict JSON with keys: campaign_name, success_definition, payoff_type, base_rate, notes.
          payoff_type must be one of revenue, leverage, learning, risk_reduction, relationship, operations.
          base_rate must be one of 10,25,40,60,75,90.
          Move title: #{move.title}
          Move description: #{move.description}
        PROMPT

        {
          campaign_name: response["campaign_name"],
          success_definition: response["success_definition"],
          payoff_type: response["payoff_type"],
          base_rate: response["base_rate"],
          notes: response["notes"]
        }
      end

      def signal_summary(move)
        signals = move.move_signals.order(created_at: :desc).limit(10).map do |signal|
          "#{signal.created_at.to_date}: #{signal.direction}/#{signal.magnitude} - #{signal.signal_type}"
        end.join("\n")

        response = request_json!(<<~PROMPT)
          Summarize these move signals in one short paragraph.
          Return strict JSON with key: summary.
          Signals:
          #{signals}
        PROMPT

        response["summary"]
      end

      def probability_hint(move)
        response = request_json!(<<~PROMPT)
          Estimate probability guidance for this move.
          Return strict JSON with keys: suggested_probability, reason.
          suggested_probability must be one of 10,25,40,60,75,90.
          Title: #{move.title}
          Success definition: #{move.success_definition}
          Advantages: #{move.advantages.join(', ')}
          Blockers: #{move.blockers.join(', ')}
        PROMPT

        {
          suggested_probability: response["suggested_probability"],
          reason: response["reason"]
        }
      end

      def parse_text(text)
        response = request_json!(<<~PROMPT)
          You are a personal productivity assistant. The user dictated or pasted unstructured text about a task they want to accomplish (a "move"). Extract structured fields from this text.

          Return strict JSON with these keys:
          - title: a short, action-oriented title (max 60 chars). Start with a verb.
          - campaign_name: the broader initiative or project this belongs to, if mentioned. null if unclear.
          - success_definition: what success looks like for this move. null if not mentioned.
          - payoff_value_raw: dollar amount if mentioned (number only, no $ sign). null if not mentioned.
          - payoff_value_normalized: relative importance 1-13 scale (1=tiny, 2=small, 3=meaningful, 5=strong, 8=major, 13=transformative). Infer from context.
          - subjective_probability: estimated chance of success as percentage (10, 25, 40, 60, 75, 90). Infer from language.
          - effort_minutes: estimated effort in minutes (10, 30, 60, 120, 240, 480). Infer from complexity.
          - due_date: if a deadline is mentioned, return as YYYY-MM-DD. null if not mentioned.
          - notes: any additional context, details, or caveats worth preserving. null if nothing extra.
          - understood: array of field names you were able to confidently extract
          - missing: array of field names you had to guess or couldn't determine

          User text:
          #{text}
        PROMPT

        response
      end

      private

      def request_json!(prompt)
        request = Net::HTTP::Post.new(OPENAI_ENDPOINT)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = {
          model: @preference.openai_model,
          input: prompt,
          text: { format: { type: "json_object" } }
        }.to_json

        response = Net::HTTP.start(OPENAI_ENDPOINT.hostname, OPENAI_ENDPOINT.port, use_ssl: true) do |http|
          http.request(request)
        end

        raise "OpenAI error #{response.code}" unless response.code.to_i.between?(200, 299)

        body = JSON.parse(response.body)
        raw = body.dig("output", 0, "content", 0, "text") || "{}"
        JSON.parse(raw)
      end
    end
  end
end
