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
