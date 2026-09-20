require "test_helper"

# What a search result shows instead of the whole body.
#
# The index produces the fragment the terms landed in, but only for a record it
# can match, and a term matched as a substring inside a longer word is one it
# cannot. So there are two sources and this picks between them, which is the
# only decision involved and the reason it is worth its own unit.
class SearchSnippetTextTest < Minitest::Test
  Subject = IntentRecord::SearchSnippet

  def test_the_fragment_the_index_found_is_preferred
    assert_equal "…retried the fetch…", Subject.text(indexed: "…retried the fetch…", body: "Whole body.")
  end

  def test_a_body_the_index_could_not_match_is_shown_from_its_beginning
    assert_equal "Whole body.", Subject.text(indexed: nil, body: "Whole body.")
  end

  # An empty fragment is what the index returns for a record whose body is
  # empty of the terms, and it is no more use to a reader than no fragment.
  def test_an_empty_fragment_falls_back_to_the_body
    assert_equal "Whole body.", Subject.text(indexed: "", body: "Whole body.")
  end

  def test_a_long_body_is_cut_short
    long = "word " * 200

    assert_operator Subject.text(indexed: nil, body: long).length, :<, long.length
  end

  def test_a_cut_body_says_that_it_was_cut
    assert_includes Subject.text(indexed: nil, body: "word " * 200), "…"
  end

  # Cutting mid-word gives the reader a fragment of a word, which reads as a
  # typo rather than as a cut.
  def test_a_body_is_cut_at_a_word_boundary
    cut = Subject.text(indexed: nil, body: "word " * 200).delete_suffix("…")

    assert_equal cut.rstrip, cut.rstrip.split.join(" ")
  end

  def test_a_short_body_is_left_whole_and_unmarked
    refute_includes Subject.text(indexed: nil, body: "Short."), "…"
  end
end
