require "test_helper"

# Reading a blame payload into the spans a reader is answered with. Nothing here
# reaches the database, so a malformed payload is refused before the store is
# asked anything and these rules can be exercised without one.
class BlameSpansTest < Minitest::Test
  Subject = IntentRecord::Blame::Spans
  FIRST = ("a" * 40).freeze
  SECOND = ("b" * 40).freeze

  def spans(lines)
    Subject.new(lines.map { |line, id| { "line" => line, "external_id" => id } }).call
  end

  def ranges(lines)
    spans(lines).map { |s| [s.from, s.to] }
  end

  def test_one_line_is_one_span_covering_only_itself
    assert_equal [[40, 40]], ranges([[40, FIRST]])
  end

  def test_neighbouring_lines_from_one_change_collapse
    assert_equal [[40, 42]], ranges([[40, FIRST], [41, FIRST], [42, FIRST]])
  end

  def test_a_different_change_starts_a_new_span
    assert_equal [[40, 40], [41, 41]], ranges([[40, FIRST], [41, SECOND]])
  end

  # Two lines from one change with someone else's line between them are two
  # places in the file, and one span across them would claim the line between.
  def test_a_change_returning_after_a_gap_is_a_second_span
    assert_equal [[10, 10], [12, 12]], ranges([[10, FIRST], [12, FIRST]])
  end

  # A blame tool walks the file, but a payload is a list and a caller may hand
  # one over sorted any way at all.
  def test_lines_given_out_of_order_are_answered_in_file_order
    assert_equal [[10, 11], [12, 12]], ranges([[12, SECOND], [11, FIRST], [10, FIRST]])
  end

  def test_a_span_carries_the_change_its_lines_came_from
    assert_equal FIRST, spans([[40, FIRST]]).sole.external_id
  end

  def test_a_payload_with_no_lines_is_refused
    error = assert_raises(IntentRecord::ValidationError) { spans([]) }
    assert_match(/line/i, error.message)
  end

  def test_a_line_without_a_change_is_refused
    assert_raises(IntentRecord::ValidationError) { Subject.new([{ "line" => 1 }]).call }
  end

  # Without this guard the entry is subscripted anyway. A string happens to
  # answer that with nil and fails later for another reason, but an array raises
  # TypeError, which is not an IntentRecord::Error and so escapes the CLI's
  # promise that every failure comes back as {"error": ...} with exit 1.
  def test_a_line_that_is_not_an_object_at_all_is_refused
    error = assert_raises(IntentRecord::ValidationError) { Subject.new([[40, FIRST]]).call }
    assert_match(/line and an external_id/, error.message)
  end

  def test_a_line_number_that_is_not_a_number_is_refused
    assert_raises(IntentRecord::ValidationError) { spans([["forty", FIRST]]) }
  end

  # Ruby's Integer() reads a leading zero as octal and 0x as hex, so "010" would
  # be answered as line 8: a wrong answer given confidently, which is worse
  # than a refusal. A number given as a string is read in base ten.
  def test_a_line_number_with_a_leading_zero_is_read_in_base_ten
    assert_equal [[10, 10]], ranges([["010", FIRST]])
  end

  def test_a_fractional_line_number_is_refused_rather_than_truncated
    assert_raises(IntentRecord::ValidationError) { spans([[3.9, FIRST]]) }
  end

  def test_a_line_number_below_one_is_refused
    assert_raises(IntentRecord::ValidationError) { spans([[0, FIRST]]) }
  end

  # The same line attributed to two changes is a contradiction in the payload,
  # and answering it would mean choosing one of them silently.
  def test_the_same_line_given_twice_is_refused
    error = assert_raises(IntentRecord::ValidationError) { spans([[40, FIRST], [40, SECOND]]) }
    assert_match(/40/, error.message)
  end
end
