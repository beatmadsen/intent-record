require "test_helper"

class LookupTest < Minitest::Test
  include IntentRecordDsl

  HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze
  OTHER = "0000000000000000000000000000000000000000".freeze

  def test_lookup_by_full_commit_hash_returns_all_intents_for_it
    a = record_intent!(summary: "first", commits: [HASH])
    b = record_intent!(summary: "second", commits: [HASH])
    record_intent!(summary: "unrelated", commits: [OTHER])

    json = run_cli_ok!("lookup", HASH)

    assert_equal [a["intent_id"], b["intent_id"]].sort, json["intents"].map { |i| i["intent_id"] }.sort
    assert_equal HASH, json["asset_version"]["external_id"]
  end

  def test_lookup_by_short_prefix_resolves_unique_match
    a = record_intent!(commits: [HASH])

    json = run_cli_ok!("lookup", HASH[0, 7])

    assert_equal [a["intent_id"]], json["intents"].map { |i| i["intent_id"] }
    assert_equal HASH, json["asset_version"]["external_id"], "the full external id is returned"
  end

  def test_lookup_rejects_ambiguous_prefix
    record_intent!(commits: ["abcdef1111111111111111111111111111111111"])
    record_intent!(commits: ["abcdef2222222222222222222222222222222222"])

    assert_cli_rejected run_cli("lookup", "abcdef"), matching: /ambiguous/i
  end

  def test_lookup_unknown_commit_is_not_found
    assert_cli_rejected run_cli("lookup", "deadbeef"), matching: /not found/i
  end

  def test_lookup_filters_by_vcs
    record_intent!(asset_versions: [{ "vcs" => "perforce", "external_id" => "777" }])

    assert_cli_ok run_cli("lookup", "777", "--vcs", "perforce")
    assert_cli_rejected run_cli("lookup", "777", "--vcs", "git"), matching: /not found/i
  end

  def test_lookup_result_includes_body_and_stakeholder_links
    record_intent!(body: "The why.", commits: [HASH],
                   stakeholder_references: [{ "system" => "jira", "uri" => "https://j/ACME-1" }])

    intent = run_cli_ok!("lookup", HASH)["intents"].sole

    assert_equal "The why.", intent["body"]
    assert_equal "https://j/ACME-1", intent["stakeholder_references"].sole["uri"]
  end
end
