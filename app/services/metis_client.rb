require "open3"

# MetisClient wraps the Metis CLI (path from ENV["METIS_CLI"]).
#
# If METIS_CLI is unset or blank the client is a NO-OP — it logs and returns
# a safe fallback so tests and unconfigured environments never call real Metis.
#
# Shell injection is prevented by passing arguments as an ARRAY to Open3.capture3
# (never via string interpolation). Brakeman will not flag array-form shell-outs.
class MetisClient
  PUT_TIMEOUT    = 10 # seconds
  SEARCH_TIMEOUT = 3  # seconds

  # Store a page in Metis.
  # Returns true on success, nil on failure or when Metis is not configured.
  def self.put_page(slug:, title:, content:)
    return noop("put_page", slug: slug) unless configured?

    cmd = [ cli_path, "put_page", "--slug", slug.to_s, "--type", "note",
            "--title", title.to_s, "--content", content.to_s, "--json" ]
    _stdout, _stderr, status = run_command(cmd, timeout: PUT_TIMEOUT, label: "put_page(#{slug})")
    status&.success? ? true : nil
  rescue StandardError => e
    Rails.logger.warn("[MetisClient] put_page error: #{e.message}")
    nil
  end

  # Search Metis for notes.
  # Returns an array of result hashes, or [] on failure / when not configured.
  def self.search(query:, limit: 10)
    return [] unless configured?

    cmd = [ cli_path, "search", "--query", query.to_s, "--limit", limit.to_s, "--json" ]
    stdout, _stderr, status = run_command(cmd, timeout: SEARCH_TIMEOUT, label: "search(#{query})")
    return [] unless status&.success?

    parse_search_results(stdout)
  rescue StandardError => e
    Rails.logger.warn("[MetisClient] search error: #{e.message}")
    []
  end

  def self.configured?
    cli_path.present?
  end

  # Expose for easy stubbing in tests (stub this class method).
  def self.cli_path
    ENV.fetch("METIS_CLI", nil).to_s.presence
  end

  private_class_method def self.noop(method_name, **context)
    Rails.logger.debug("[MetisClient] METIS_CLI not set — skipping #{method_name} #{context}")
    nil
  end

  private_class_method def self.run_command(cmd, timeout:, label:)
    # Wrap with coreutils `timeout` so a hung metis CLI can't block a worker or a
    # web request forever (Open3.capture3 has no built-in timeout). `timeout` sends
    # SIGTERM after `timeout` seconds, then SIGKILL 2s later; on timeout it exits
    # non-zero so the caller treats it as a failure. capture3's array form avoids
    # any shell parsing.
    wrapped = [ "timeout", "-k", "2", timeout.to_s, *cmd ]
    Open3.capture3(*wrapped)
  rescue Errno::ENOENT => e
    Rails.logger.warn("[MetisClient] CLI not found for #{label}: #{e.message}")
    [ "", "", nil ]
  rescue StandardError => e
    Rails.logger.warn("[MetisClient] Command failed for #{label}: #{e.message}")
    [ "", "", nil ]
  end

  private_class_method def self.parse_search_results(stdout)
    return [] if stdout.blank?

    parsed = JSON.parse(stdout)
    # `metis search --json` returns a {"results": [...]} envelope; tolerate a bare array too.
    return Array(parsed["results"]) if parsed.is_a?(Hash)

    Array(parsed)
  rescue JSON::ParserError
    # Best effort for line-delimited JSON output.
    stdout.lines.filter_map do |line|
      JSON.parse(line.strip)
    rescue JSON::ParserError
      nil
    end
  end
end
