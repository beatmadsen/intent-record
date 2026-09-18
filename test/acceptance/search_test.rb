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
