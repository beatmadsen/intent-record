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
  # typo rather than as a cut. Distinct words, so a cut inside one is a word
  # that was never in the body; a body of one repeated word cannot tell.
  def test_a_body_is_cut_at_a_word_boundary
    words = %w[alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima]
    body = Array.new(60) { |i| words[i % words.size] }.join(" ")

    cut = Subject.text(indexed: nil, body: body).delete_suffix("…")

    assert_includes words, cut.split.last
  end

  # Japanese and Chinese prose has no spaces, and so does a long url or a hash.
  # A cut that looks for a word boundary and finds none must still show the
  # text, not an ellipsis on its own.
  def test_a_body_with_no_spaces_is_still_shown
    text = Subject.text(indexed: nil, body: "字" * 300)

    assert_equal "#{"字" * Subject::FALLBACK_LENGTH}…", text
  end

  def test_a_short_body_is_left_whole_and_unmarked
    refute_includes Subject.text(indexed: nil, body: "Short."), "…"
  end
end

# The boundary of the cut. A body exactly at the limit needs no cutting, and
# cutting it anyway would add an ellipsis promising text that does not exist.
class SearchSnippetBoundaryTest < Minitest::Test
  Subject = IntentRecord::SearchSnippet

  def body_of(length)
    "w" * length
  end

  def test_a_body_exactly_at_the_limit_is_left_whole
    body = body_of(Subject::FALLBACK_LENGTH)

    assert_equal body, Subject.text(indexed: nil, body: body)
  end

  def test_a_body_one_character_past_the_limit_is_cut
    text = Subject.text(indexed: nil, body: body_of(Subject::FALLBACK_LENGTH + 1))

    assert_equal "#{body_of(Subject::FALLBACK_LENGTH)}…", text
  end
end
