require "test_helper"
require "tempfile"

class MetisClientTest < ActiveSupport::TestCase
  # Ensure METIS_CLI is always unset in tests — never call real Metis.
  setup do
    @original_metis_cli = ENV.delete("METIS_CLI")
  end

  teardown do
    ENV["METIS_CLI"] = @original_metis_cli if @original_metis_cli
  end

  # ── No-op when METIS_CLI is unset ─────────────────────────────────────

  test "configured? returns false when METIS_CLI is not set" do
    assert_not MetisClient.configured?
  end

  test "put_page returns nil (no-op) when METIS_CLI is unset" do
    result = MetisClient.put_page(slug: "test/slug", title: "Test", content: "body")
    assert_nil result
  end

  test "search returns empty array when METIS_CLI is unset" do
    result = MetisClient.search(query: "test")
    assert_equal [], result
  end

  test "configured? returns true when METIS_CLI is set" do
    ENV["METIS_CLI"] = "/usr/local/bin/metis"
    assert MetisClient.configured?
  ensure
    ENV.delete("METIS_CLI")
  end

  # ── Shell injection prevention — verified by source inspection ────────

  test "Open3.capture3 is called with array splat to prevent shell injection" do
    source = File.read(Rails.root.join("app/services/metis_client.rb"))
    assert_match(/Open3\.capture3\(\*\w+\)/, source,
      "MetisClient must call Open3.capture3 with an array splat, not string interpolation")
    assert_no_match(/`.*\#{/, source,
      "MetisClient must not use backtick shell interpolation")
    assert_no_match(/system\(".*\#{/, source,
      "MetisClient must not use shell string in system()")
  end

  # ── CLI binary not found (Errno::ENOENT) ─────────────────────────────

  test "put_page returns nil when CLI binary is not found (Errno::ENOENT)" do
    ENV["METIS_CLI"] = "/this/path/does/not/exist/metis_binary_xyz"
    result = nil
    assert_nothing_raised do
      result = MetisClient.put_page(slug: "s", title: "t", content: "c")
    end
    assert_nil result
  ensure
    ENV.delete("METIS_CLI")
  end

  test "search returns [] when CLI binary is not found (Errno::ENOENT)" do
    ENV["METIS_CLI"] = "/this/path/does/not/exist/metis_binary_xyz"
    result = nil
    assert_nothing_raised do
      result = MetisClient.search(query: "q")
    end
    assert_equal [], result
  ensure
    ENV.delete("METIS_CLI")
  end

  # ── Configured but CLI exits non-zero ─────────────────────────────────

  test "search returns [] when CLI exits non-zero" do
    # /usr/bin/false always exits 1
    ENV["METIS_CLI"] = "/usr/bin/false"
    result = MetisClient.search(query: "test")
    assert_equal [], result
  ensure
    ENV.delete("METIS_CLI")
  end

  test "put_page returns nil when CLI exits non-zero" do
    ENV["METIS_CLI"] = "/usr/bin/false"
    result = MetisClient.put_page(slug: "s", title: "t", content: "c")
    assert_nil result
  ensure
    ENV.delete("METIS_CLI")
  end

  # ── Command construction (locks the metis CLI contract) ───────────────
  # Uses a temporary fake "metis" executable so we exercise the real Open3 path
  # without stubbing and without touching real Metis.

  # Writes args (one per line) to args_file and prints stdout_text; exits 0.
  def with_fake_metis(stdout_text: "{}")
    args_file = Tempfile.new("metis-args")
    script = Tempfile.new([ "fake-metis", ".sh" ])
    script.write(<<~SH)
      #!/usr/bin/env bash
      : > "#{args_file.path}"
      for a in "$@"; do printf '%s\\n' "$a" >> "#{args_file.path}"; done
      cat <<'OUT'
      #{stdout_text}
      OUT
    SH
    script.close
    File.chmod(0o755, script.path)
    ENV["METIS_CLI"] = script.path
    yield args_file
  ensure
    ENV.delete("METIS_CLI")
    script&.unlink
    args_file&.unlink
  end

  test "put_page invokes the 'put_page' subcommand with --type note and content" do
    with_fake_metis do |args_file|
      assert MetisClient.put_page(slug: "projects/moves-notes/abc", title: "T", content: "B")
      args = File.read(args_file.path).lines(chomp: true)
      assert_equal "put_page", args.first
      assert_includes args, "--slug"
      assert_includes args, "projects/moves-notes/abc"
      assert_includes args, "--type"
      assert_includes args, "note"
      assert_includes args, "--content"
      assert_includes args, "B"
    end
  end

  test "search unwraps the {\"results\":[...]} envelope from --json output" do
    payload = JSON.generate("results" => [ { "slug" => "x", "text" => "hello" } ])
    with_fake_metis(stdout_text: payload) do |args_file|
      results = MetisClient.search(query: "hello")
      assert_equal 1, results.size
      assert_equal "x", results.first["slug"]
      assert_includes File.read(args_file.path).lines(chomp: true), "--json"
    end
  end
end
