require "test_helper"

# SQLite only honours the LIKE escape character when an ESCAPE clause is present,
# so a query containing % or _ is the case that tells a correct search from one
# that quietly matches everything.
class LikeEscapingTest < Minitest::Test
  include IntentRecordDsl

  def test_search_matches_a_literal_percent
    hit = record_intent!(summary: "100% done", body: "b")
    record_intent!(summary: "100 percent", body: "b")

    assert_equal([hit["intent_id"]], run_cli_ok!("search", "100%")["intents"].map { |r| r["intent_id"] })
  end

  def test_search_matches_a_literal_underscore
    hit = record_intent!(summary: "done_now", body: "b")
    record_intent!(summary: "done now", body: "b")

    assert_equal([hit["intent_id"]], run_cli_ok!("search", "done_now")["intents"].map { |r| r["intent_id"] })
  end

  def test_by_source_contains_matches_a_literal_percent
    hit = record_intent!(stakeholder_references: [{ "system" => "web", "uri" => "https://w/100%25_done" }])
    record_intent!(stakeholder_references: [{ "system" => "web", "uri" => "https://w/100x25xdone" }])

    found = run_cli_ok!("by-source", "100%25_", "--contains")["intents"].map { |r| r["intent_id"] }

    assert_equal([hit["intent_id"]], found)
  end
end
