require "test_helper"

class RecordWithCommitsTest < Minitest::Test
  include IntentRecordDsl

  HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze

  def test_links_intent_to_git_commit_by_default_vcs
    json = record_intent!(commits: [HASH])

    record = IntentRecord::Models::IntentRecord.find_by!(global_id: json["intent_id"])
    version = record.asset_versions.sole
    assert_equal HASH, version.external_id
    assert_equal "git", version.vcs_system.name
  end

  def test_accepts_explicit_asset_versions_with_vcs_name
    record_intent!(asset_versions: [{ "vcs" => "Perforce", "external_id" => "12345" }])

    version = IntentRecord::Models::AssetVersion.sole
    assert_equal "perforce", version.vcs_system.name, "vcs names are normalised to lowercase"
  end

  def test_two_intents_on_same_commit_share_one_asset_version
    record_intent!(commits: [HASH])
    record_intent!(commits: [HASH])

    assert_equal 1, IntentRecord::Models::AssetVersion.count
    assert_equal 2, IntentRecord::Models::AssetVersion.sole.intent_records.count
  end

  def test_rejects_blank_commit_hash
    result = run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => [" "] })

    assert_cli_rejected result, matching: /commit/
  end
end
