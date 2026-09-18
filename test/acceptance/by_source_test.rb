require "test_helper"

class BySourceTest < Minitest::Test
  include IntentRecordDsl

  URI = "https://acme.atlassian.net/browse/ACME-42".freeze

  def test_lists_intents_and_their_commits_for_a_stakeholder_uri
    a = record_intent!(commits: ["1111111111111111111111111111111111111111"],
                       stakeholder_references: [{ "system" => "jira", "uri" => URI }])
    record_intent!(stakeholder_references: [{ "system" => "jira",
                                              "uri" => "https://acme.atlassian.net/browse/ACME-43" }])

    json = run_cli_ok!("by-source", URI)

    assert_equal([a["intent_id"]], json["intents"].map { |i| i["intent_id"] })
    assert_equal "1111111111111111111111111111111111111111", json["intents"].sole["asset_versions"].sole["external_id"]
    assert_equal "jira", json["sources"].sole["system"]
  end

  def test_unknown_uri_returns_empty_list_not_error
    json = run_cli_ok!("by-source", "https://nowhere.example/x")

    assert_equal [], json["intents"]
  end

  def test_substring_match_finds_ticket_key_across_systems
    a = record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => URI }])
    b = record_intent!(stakeholder_references: [{ "system" => "confluence",
                                                  "uri" => "https://acme.atlassian.net/wiki/ACME-42-design" }])

    json = run_cli_ok!("by-source", "ACME-42", "--contains")

    assert_equal [a["intent_id"], b["intent_id"]].sort, json["intents"].map { |i| i["intent_id"] }.sort
  end
end

class BySourceCommitsTest < Minitest::Test
  include IntentRecordDsl

  URI = "https://acme.atlassian.net/browse/ACME-42".freeze
  JIRA = { "system" => "jira", "uri" => URI }.freeze
  A = "1111111111111111111111111111111111111111".freeze
  B = "2222222222222222222222222222222222222222".freeze

  def test_top_level_asset_versions_aggregate_distinct_commits_across_intents_in_order
    record_intent!(summary: "first", commits: [A], stakeholder_references: [JIRA])
    record_intent!(summary: "second", commits: [A, B], stakeholder_references: [JIRA])

    json = run_cli_ok!("by-source", URI)

    assert_equal([A, B], json["asset_versions"].map { |v| v["external_id"] })
    assert_equal({ "vcs" => "git", "external_id" => A }, json["asset_versions"].first)
  end
end
