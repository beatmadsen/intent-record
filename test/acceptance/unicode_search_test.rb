require "test_helper"

# SQLite's own LOWER folds ASCII only, which is why the connection defines ULOWER.
class UnicodeSearchTest < Minitest::Test
  include IntentRecordDsl

  def test_a_lowercase_query_matches_a_capitalised_non_ascii_summary
    hit = record_intent!(summary: "Ünïcödé 日本語", body: "b")

    assert_equal([hit["intent_id"]], run_cli_ok!("search", "ünïcödé")["intents"].map { |r| r["intent_id"] })
  end

  def test_an_uppercase_query_matches_a_capitalised_non_ascii_summary
    hit = record_intent!(summary: "Ünïcödé 日本語", body: "b")

    assert_equal([hit["intent_id"]], run_cli_ok!("search", "ÜNÏCÖDÉ")["intents"].map { |r| r["intent_id"] })
  end
end
