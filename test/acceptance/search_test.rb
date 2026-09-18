require "test_helper"

class SearchTest < Minitest::Test
  include IntentRecordDsl

  def test_search_matches_terms_in_summary_or_body_case_insensitively
    hit = record_intent!(summary: "Retry HTTP fetch", body: "Flaky network.")
    also = record_intent!(summary: "Other", body: "Adds a retry budget.")
    record_intent!(summary: "Nope", body: "Nothing here.")

    json = run_cli_ok!("search", "retry")

    assert_equal [hit["intent_id"], also["intent_id"]].sort, json["results"].map { |r| r["intent_id"] }.sort
  end

  def test_search_match_all_requires_every_term
    both = record_intent!(summary: "Retry fetch", body: "with backoff")
    record_intent!(summary: "Retry fetch", body: "no delay")

    json = run_cli_ok!("search", "retry", "backoff", "--match", "all")

    assert_equal([both["intent_id"]], json["results"].map { |r| r["intent_id"] })
  end

  def test_search_results_include_commits
    record_intent!(summary: "Retry", commits: ["abc1234abc1234abc1234abc1234abc1234abc12"])

    result = run_cli_ok!("search", "retry")["results"].sole

    assert_equal "abc1234abc1234abc1234abc1234abc1234abc12", result["asset_versions"].sole["external_id"]
  end

  def test_search_without_terms_is_rejected
    assert_cli_rejected run_cli("search"), matching: /term/
  end
end

class SearchStakeholderFieldsTest < Minitest::Test
  include IntentRecordDsl

  def test_search_matches_ticket_key_in_stakeholder_uri
    hit = record_intent!(summary: "Nothing telling", body: "here",
                         stakeholder_references: [{ "system" => "jira", "uri" => "https://j/browse/ACME-42" }])
    record_intent!(summary: "Other", body: "thing")

    json = run_cli_ok!("search", "acme-42")

    assert_equal([hit["intent_id"]], json["results"].map { |r| r["intent_id"] })
  end

  def test_search_matches_stakeholder_title_with_match_all_across_fields
    jira = { "system" => "jira", "uri" => "https://j/1", "title" => "Flaky fetch in CI" }
    hit = record_intent!(summary: "Retry fetches", body: "with backoff", stakeholder_references: [jira])
    record_intent!(summary: "Retry fetches", body: "with backoff")

    json = run_cli_ok!("search", "flaky", "backoff", "--match", "all")

    assert_equal([hit["intent_id"]], json["results"].map { |r| r["intent_id"] })
  end

  def test_search_returns_each_intent_once_despite_multiple_matching_sources
    refs = [{ "system" => "jira", "uri" => "https://j/ACME-1" },
            { "system" => "confluence", "uri" => "https://c/ACME-1" }]
    record_intent!(stakeholder_references: refs)

    assert_equal 1, run_cli_ok!("search", "acme")["results"].size
  end
end
