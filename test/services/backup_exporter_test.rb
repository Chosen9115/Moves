require "test_helper"

class BackupExporterTest < ActiveSupport::TestCase
  test "returns campaigns moves and signals payload" do
    payload = BackupExporter.call

    assert payload[:campaigns].any?
    assert payload[:moves].any?
    assert payload[:signals].any?
  end
end
