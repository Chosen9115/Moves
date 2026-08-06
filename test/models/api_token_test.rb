require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "generate! creates a record and returns raw token" do
    record, raw = ApiToken.generate!(name: "test_client", scopes: "moves:read")

    assert record.persisted?
    assert_equal "test_client", record.name
    assert_equal "moves:read", record.scopes
    assert_not_nil raw
    assert raw.length > 20
  end

  test "generate! stores digest, not raw token" do
    record, raw = ApiToken.generate!(name: "test_client2", scopes: "moves:read")

    assert_not_equal raw, record.token_digest
    assert_equal Digest::SHA256.hexdigest(raw), record.token_digest
  end

  test "authenticate returns token for valid raw token" do
    record, raw = ApiToken.generate!(name: "auth_test", scopes: "moves:read")

    found = ApiToken.authenticate(raw)

    assert_equal record.id, found.id
  end

  test "authenticate updates last_used_at" do
    _record, raw = ApiToken.generate!(name: "auth_ts_test", scopes: "moves:read")

    assert_changes -> { ApiToken.find_by(name: "auth_ts_test").last_used_at } do
      ApiToken.authenticate(raw)
    end
  end

  test "authenticate returns nil for unknown token" do
    assert_nil ApiToken.authenticate("totally_bogus_token_xyz")
  end

  test "authenticate returns nil for revoked token" do
    record, raw = ApiToken.generate!(name: "revoked_test", scopes: "moves:read")
    record.revoke!

    assert_nil ApiToken.authenticate(raw)
  end

  test "authenticate returns nil for blank input" do
    assert_nil ApiToken.authenticate(nil)
    assert_nil ApiToken.authenticate("")
  end

  test "has_scope? returns true for matching scope" do
    record, = ApiToken.generate!(name: "scope_test", scopes: "moves:read moves:write")

    assert record.has_scope?("moves:read")
    assert record.has_scope?("moves:write")
  end

  test "has_scope? returns false for missing scope" do
    record, = ApiToken.generate!(name: "scope_test2", scopes: "moves:read")

    assert_not record.has_scope?("moves:write")
  end

  test "active? is true when not revoked" do
    record, = ApiToken.generate!(name: "active_test", scopes: "moves:read")

    assert record.active?
    assert_not record.revoked?
  end

  test "revoked? is true after revoke!" do
    record, = ApiToken.generate!(name: "revoke_test", scopes: "moves:read")
    record.revoke!

    assert record.revoked?
    assert_not record.active?
  end

  test "validates presence of name, token_digest, scopes" do
    token = ApiToken.new
    assert_not token.valid?
    assert token.errors[:name].any?
    assert token.errors[:scopes].any?
  end
end
