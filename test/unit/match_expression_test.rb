require "test_helper"

# FTS5 reads its query as an expression language, so a term a user typed is not
# a term FTS5 will accept: bare punctuation is a syntax error and a bare AND is
# an operator. Every term goes through here and comes out a quoted phrase.
class MatchExpressionTest < Minitest::Test
  Subject = IntentRecord::MatchExpression

  def test_a_word_becomes_a_quoted_phrase
    assert_equal '"retry"', Subject.for(["retry"])
  end

  def test_terms_are_joined_so_a_record_matching_any_of_them_ranks
    assert_equal '"retry" OR "backoff"', Subject.for(%w[retry backoff])
  end

  # A bare 100% is "fts5: syntax error near %". Quoting is what makes a term
  # the user typed survive the parser.
  def test_punctuation_is_carried_inside_the_phrase_rather_than_parsed
    assert_equal '"100%"', Subject.for(["100%"])
  end

  # The one character quoting cannot carry as itself; FTS5 doubles it.
  def test_a_double_quote_is_doubled_so_the_phrase_stays_closed
    assert_equal '"say ""so"""', Subject.for(['say "so"'])
  end

  # A term that tokenises to nothing contributes no phrase; an empty MATCH is a
  # syntax error, so what is left over has to be nil rather than "".
  def test_terms_that_hold_no_searchable_token_yield_nothing_to_match
    assert_nil Subject.for(["-", "  "])
  end

  def test_no_terms_yield_nothing_to_match
    assert_nil Subject.for([])
  end
end

# Which terms the index is allowed to answer for at all.
#
# The index tokenises, so it drops punctuation: `100%` is indexed as `100` and
# would match a record that only ever said `100 percent`. Measured, so is
# `done_now` against `done now`. A term carrying punctuation is therefore a term
# the index cannot be trusted with, and substring matching keeps it literal.
class MatchExpressionWordTermsTest < Minitest::Test
  Subject = IntentRecord::MatchExpression

  def test_a_plain_word_may_be_answered_by_the_index
    assert Subject.word?("retrying")
  end

  def test_a_word_with_digits_may_be_answered_by_the_index
    assert Subject.word?("sha256")
  end

  # Several words are still words. The index reads them as a phrase, which is
  # the same thing the substring match asks for.
  def test_a_run_of_words_may_be_answered_by_the_index
    assert Subject.word?("retry the fetch")
  end

  def test_a_non_ascii_word_may_be_answered_by_the_index
    assert Subject.word?("ünïcödé")
  end

  def test_a_term_carrying_punctuation_may_not_be
    refute Subject.word?("100%")
    refute Subject.word?("done_now")
    refute Subject.word?("acme-42")
  end

  def test_a_term_with_no_letters_or_digits_may_not_be
    refute Subject.word?("---")
  end
end
