require "test_helper"

# Substring search answers newest first, which says nothing about which hit
# answers the question. These pin the ordering a reader needs: the record the
# search is about, ahead of the one that merely says the word somewhere.
class SearchRankingTest < Minitest::Test
  include IntentRecordDsl

  # Recorded after the title match, so newest-first would put it first. Only
  # relevance puts the title match ahead of it, which is what lets this fail.
  def test_a_summary_match_outranks_a_passing_mention_deep_in_a_body
    on_topic = record_intent!(summary: "Retry flaky fetches with backoff", body: "Short reasoning.")
    in_passing = record_intent!(summary: "Rename the config loader",
                                body: "#{"Unrelated prose. " * 60}Left the retry alone.")

    ranked = run_cli_ok!("search", "retry")["intents"].map { |r| r["intent_id"] }

    assert_equal [on_topic["intent_id"], in_passing["intent_id"]], ranked
  end
end
