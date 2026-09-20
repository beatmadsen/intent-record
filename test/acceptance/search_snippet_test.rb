require "test_helper"

# A search result carries the whole body, which is the right thing for an agent
# reading one record and the wrong thing for a person scanning two hundred. The
# snippet is the part worth reading first: where in the body the terms landed.
class SearchSnippetTest < Minitest::Test
  include IntentRecordDsl

  LONG_PROSE = "Unrelated prose about other things. ".freeze

  # The match buried in the middle of a body far longer than any fragment.
  def long_body
    "#{LONG_PROSE * 40}We retried the fetch here.#{" And then more prose." * 40}"
  end

  def test_a_result_carries_the_fragment_of_the_body_the_terms_landed_in
    record_intent!(summary: "Rename the config loader", body: long_body)

    snippet = run_cli_ok!("search", "retry")["intents"].sole["snippet"]

    assert_includes snippet, "retried the fetch"
  end

  def test_the_fragment_is_shorter_than_the_body_it_came_from
    record_intent!(summary: "Rename the config loader", body: long_body)

    result = run_cli_ok!("search", "retry")["intents"].sole

    assert_operator result["snippet"].length, :<, result["body"].length
  end

  # A term matched only as a substring inside a longer word is one the index
  # cannot see, so it can offer no fragment. The result still has to carry one,
  # or a reader scanning the list meets a blank where every other row has text.
  def test_a_result_the_index_cannot_match_still_carries_a_fragment
    record_intent!(summary: "Refactoring the loader", body: "The reason it had to move.")

    snippet = run_cli_ok!("search", "factor")["intents"].sole["snippet"]

    assert_includes snippet, "The reason it had to move."
  end

  def test_every_result_carries_a_fragment
    record_intent!(summary: "Retry fetch", body: "Short reasoning.")
    record_intent!(summary: "Refactoring the loader", body: "The reason it had to move.")

    snippets = run_cli_ok!("search", "retry", "factor")["intents"].map { |r| r["snippet"] }

    assert_equal 2, snippets.size
    refute_includes snippets, nil
  end
end
