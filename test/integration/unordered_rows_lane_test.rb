require "test_helper"

# The chaos lane is itself a measurement, and an unverified measurement licenses
# a belief it has not earned: a lane that reversed nothing would report green
# over the same unpinned ordering it exists to expose. These ask whether it
# reverses what it claims to, and leaves alone what it claims to leave alone.
class UnorderedRowsPredicateTest < Minitest::Test
  TWO_ROWS = [[1], [2]].freeze

  def result(rows)
    ActiveRecord::Result.new(%w[id], rows)
  end

  def test_a_select_without_an_order_by_is_reversed
    assert UnorderedRows.reversible?("SELECT id FROM intent_records", result(TWO_ROWS))
  end

  def test_a_select_that_names_its_order_is_left_alone
    refute UnorderedRows.reversible?("SELECT id FROM intent_records ORDER BY id", result(TWO_ROWS))
  end

  # Reversing one row changes nothing, and counting it would let the lane report
  # that it bit when it did not.
  def test_a_single_row_result_is_left_alone
    refute UnorderedRows.reversible?("SELECT id FROM intent_records", result([[1]]))
  end

  def test_a_statement_that_is_not_a_query_is_left_alone
    refute UnorderedRows.reversible?("INSERT INTO vcs_systems (name) VALUES ('git')", result(TWO_ROWS))
  end
end

# Defined only when the lane is on: with it off there is no reversal to specify,
# and a test that skips in every run of the gate is a line of noise that teaches
# people to read past the skip count.
if UnorderedRows.enabled?
  class UnorderedRowsLaneTest < Minitest::Test
    include DbTestSetup

    # `SELECT *` has to read every column, so SQLite cannot answer it from a
    # covering index and walks the table in rowid order. That is the one shape
    # whose natural answer is predictable enough to compare a reversal against.
    # `pluck(:id)` would not do: SQLite answers it from the index on name, in name
    # order, which is the very assumption this lane exists to break.
    def test_the_lane_reverses_the_rows_a_query_without_an_order_by_returns
      rowid_order = IntentRecord::Models::VcsSystem.order(:id).pluck(:id)

      assert_equal rowid_order.reverse, IntentRecord::Models::VcsSystem.all.map(&:id)
    end
  end
end
