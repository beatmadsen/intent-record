require "test_helper"

# The SQL that decides the order a search answers in. It is a template with a
# placeholder rather than finished SQL, so building it needs no database and the
# one value that comes from the user is bound rather than pasted.
class SearchRankingTest < Minitest::Test
  Subject = IntentRecord::SearchRanking

  def test_the_order_names_a_tie_break_so_equally_ranked_records_have_an_order
    assert_match(/created_at DESC, intent_records\.id DESC/, Subject.order_template)
  end

  def test_the_best_relevance_comes_first
    assert_match(/ASC, intent_records\.created_at/, Subject.order_template)
  end

  # A record the index cannot see has no relevance at all, and NULL sorts to one
  # end or the other depending on the plan rather than on anything intended.
  def test_a_record_the_index_cannot_see_is_given_a_score_rather_than_null
    assert_match(/COALESCE\(.*, 0\.0\) ASC/, Subject.order_template)
  end

  # The user's terms reach SQLite as a bound value. Building the template must
  # not need a connection, which is also what proves nothing is pasted into it.
  def test_the_match_expression_is_left_as_a_placeholder
    assert_includes Subject.order_template, "MATCH ?"
  end

  def test_the_summary_is_weighted_above_the_body
    assert_operator Subject::SUMMARY_WEIGHT, :>, Subject::BODY_WEIGHT
  end
end
