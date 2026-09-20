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

# Substring matching asks the reader to guess which form of a word the writer
# used. These pin the widening that stemming buys, and the line it must not
# cross: a term that is plainly a word is matched as a word, and a term carrying
# punctuation is matched as the literal the person typed.
class SearchStemmingTest < Minitest::Test
  include IntentRecordDsl

  def found(*argv)
    run_cli_ok!("search", *argv)["intents"].map { |r| r["intent_id"] }
  end

  def test_a_term_matches_another_form_of_the_same_word
    hit = record_intent!(summary: "Retry the fetch", body: "Because flaky.")

    assert_equal([hit["intent_id"]], found("retrying"))
  end

  # `retried` does not contain `retry`, so substring matching cannot reach it and
  # only the stemmer can. `retrying` would have made this test green without a
  # stemmer, since it carries `retry` inside it.
  def test_a_stem_match_reaches_the_body_as_well_as_the_summary
    hit = record_intent!(summary: "Nothing telling", body: "We retried the fetch.")

    assert_equal([hit["intent_id"]], found("retry"))
  end

  # The line stemming must not cross. `100%` tokenises to `100`, so a term that
  # carried punctuation into the index would match the record that never wrote
  # the punctuation at all. LikeEscapingTest pins the same rule from the other
  # side; this says why the two cannot share one code path.
  def test_a_term_carrying_punctuation_is_matched_as_the_literal_it_is
    hit = record_intent!(summary: "100% done", body: "b")
    record_intent!(summary: "100 percent", body: "b")

    assert_equal([hit["intent_id"]], found("100%"))
  end

  def test_an_underscored_term_is_matched_as_the_literal_it_is
    hit = record_intent!(summary: "done_now", body: "b")
    record_intent!(summary: "done now", body: "b")

    assert_equal([hit["intent_id"]], found("done_now"))
  end
end
