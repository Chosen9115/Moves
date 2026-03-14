require "test_helper"

class BackupImporterTest < ActiveSupport::TestCase
  test "imports exported payload with upsert behavior" do
    json = JSON.generate(BackupExporter.call)

    MoveSignal.delete_all
    Move.delete_all
    Campaign.delete_all

    assert_difference("Campaign.count", 2) do
      assert_difference("Move.count", 2) do
        assert_difference("MoveSignal.count", 2) do
          BackupImporter.call(json)
        end
      end
    end

    assert_no_difference("Campaign.count") do
      assert_no_difference("Move.count") do
        assert_no_difference("MoveSignal.count") do
          BackupImporter.call(json)
        end
      end
    end
  end
end
