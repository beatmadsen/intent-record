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

    ranked = found_by_search("retry")

    assert_equal [on_topic["intent_id"], in_passing["intent_id"]], ranked
  end
end

# What COALESCE(relevance, 0.0) exists for. A record the index matched has a
# negative score and a record found only as a substring has none, and the two
# must sort in that order rather than wherever NULL happens to fall.
class SearchSubstringOnlyRankTest < Minitest::Test
  include IntentRecordDsl

  def test_a_record_the_index_matched_outranks_one_found_only_as_a_substring
    by_substring = record_intent!(summary: "Refactoring the loader", body: "b")
    by_index = record_intent!(summary: "Retry the fetch", body: "b")

    ranked = found_by_search("retry", "factor")

    assert_equal [by_index["intent_id"], by_substring["intent_id"]], ranked
  end
end

# Substring matching asks the reader to guess which form of a word the writer
# used. These pin the widening that stemming buys, and the line it must not
# cross: a term that is plainly a word is matched as a word, and a term carrying
# punctuation is matched as the literal the person typed.
class SearchStemmingTest < Minitest::Test
  include IntentRecordDsl

  def test_a_term_matches_another_form_of_the_same_word
    hit = record_intent!(summary: "Retry the fetch", body: "Because flaky.")

    assert_equal([hit["intent_id"]], found_by_search("retrying"))
  end

  # `retried` does not contain `retry`, so substring matching cannot reach it and
  # only the stemmer can. `retrying` would have made this test green without a
  # stemmer, since it carries `retry` inside it.
  def test_a_stem_match_reaches_the_body_as_well_as_the_summary
    hit = record_intent!(summary: "Nothing telling", body: "We retried the fetch.")

    assert_equal([hit["intent_id"]], found_by_search("retry"))
  end

  # The line stemming must not cross. `100%` tokenises to `100`, so a term that
  # carried punctuation into the index would match the record that never wrote
  # the punctuation at all. LikeEscapingTest pins the same rule from the other
  # side; this says why the two cannot share one code path.
  def test_a_term_carrying_punctuation_is_matched_as_the_literal_it_is
    hit = record_intent!(summary: "100% done", body: "b")
    record_intent!(summary: "100 percent", body: "b")

    assert_equal([hit["intent_id"]], found_by_search("100%"))
  end

  def test_an_underscored_term_is_matched_as_the_literal_it_is
    hit = record_intent!(summary: "done_now", body: "b")
    record_intent!(summary: "done now", body: "b")

    assert_equal([hit["intent_id"]], found_by_search("done_now"))
  end
end

# A term is one argv word, so the shell's own quoting is what asks for a phrase.
# Nothing in the CLI parses quotes, and these say the behaviour that falls out of
# that is the behaviour a person quoting a phrase expects.
class SearchPhraseTest < Minitest::Test
  include IntentRecordDsl

  def test_a_quoted_phrase_matches_the_words_in_that_order
    hit = record_intent!(summary: "Retry the fetch on failure", body: "b")

    assert_equal([hit["intent_id"]], found_by_search("retry the fetch"))
  end

  def test_a_quoted_phrase_does_not_match_the_same_words_apart
    record_intent!(summary: "Retry it, then fetch again", body: "b")

    assert_empty found_by_search("retry the fetch")
  end

  # The words are still stemmed inside a phrase, so the phrase does not have to
  # be quoted in the form the writer happened to use.
  def test_a_quoted_phrase_matches_another_form_of_its_words
    hit = record_intent!(summary: "Nothing telling", body: "We retried the fetches twice.")

    assert_equal([hit["intent_id"]], found_by_search("retry the fetch"))
  end
end

# A term of pure punctuation is a term the index cannot read at all: it holds no
# token, and an empty MATCH expression is a syntax error rather than an
# expression that matches nothing. Substring matching still answers it, so the
# search works and only the ranking has nothing to rank.
class SearchUnrankableTermTest < Minitest::Test
  include IntentRecordDsl

  def test_a_term_with_no_searchable_token_still_finds_it_as_a_substring
    hit = record_intent!(summary: "Uses ... as a separator", body: "b")
    record_intent!(summary: "Plain record", body: "b")

    found = found_by_search("...")

    assert_equal([hit["intent_id"]], found)
  end

  # Nothing to rank by leaves the tie-break, which is the order `recent` answers
  # in. Without it the rows come back in whatever order the plan produces.
  def test_results_with_nothing_to_rank_by_are_answered_newest_first
    older = record_intent!(summary: "First ... separator", body: "b")
    newer = record_intent!(summary: "Second ... separator", body: "b")

    found = found_by_search("...")

    assert_equal([newer["intent_id"], older["intent_id"]], found)
  end

  def test_a_term_with_no_searchable_token_still_carries_a_fragment
    record_intent!(summary: "Uses ... as a separator", body: "The reason it is here.")

    snippet = run_cli_ok!("search", "...")["intents"].sole["snippet"]

    assert_equal "The reason it is here.", snippet
  end
end
