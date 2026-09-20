require "test_helper"

# How the ranking is asked for, which the query plan states directly and a
# timing test could only hint at. Measured on a store of twenty-five thousand
# records: bm25 read through a correlated subquery costs SQLite a scan of the
# whole match set for every candidate row, eight seconds for a common word,
# while computing it once over the match set costs a hundredth of a second.
# The two answer identically, so nothing but the plan can tell them apart.
class SearchRankingPlanTest < Minitest::Test
  include DbTestSetup

  def plan_for_search(*terms)
    IntentRecord::Commands::Record.new.call("summary" => "Retry the fetch", "body" => "b")
    sql = queries_while { IntentRecord::Commands::Search.new(terms: terms).call }
          .find { |q| q.include?("intent_search") && q.lstrip.start_with?("SELECT") }
    refute_nil sql, "no search query touched the index"
    IntentRecord::Models::IntentRecord.connection.select_rows("EXPLAIN QUERY PLAN #{sql}").map { |r| r[3] }
  end

  def test_relevance_is_computed_once_for_the_search_rather_than_once_per_record
    plan = plan_for_search("retry")

    assert plan.any? { |step| step.match?(/MATERIALIZE/) }, "ranking is not materialised once:\n  #{plan.join("\n  ")}"
  end

  # Membership does ask the index per record, once per term, through the EXISTS
  # arm: measured at about twenty-five microseconds a row, because a MATCH with
  # a rowid equality is a lookup rather than a scan. The relevance and the
  # fragment used to be two more such questions per record, and those are the
  # ones the materialised subquery replaces. So the count is pinned exactly:
  # a plan carrying the old form as well would answer identically and cost
  # thirty times as much.
  def test_the_only_per_record_question_put_to_the_index_is_membership_one_per_term
    assert_equal 1, correlated_index_lookups(plan_for_search("retry"))
    assert_equal 2, correlated_index_lookups(plan_for_search("retry", "fetch"))
  end

  def correlated_index_lookups(plan)
    plan.each_cons(2).count { |a, b| a.match?(/CORRELATED SCALAR SUBQUERY/) && b.match?(/intent_search/) }
  end
end
