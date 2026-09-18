require "test_helper"

class ArgvParserTest < Minitest::Test
  def test_take_flag_answers_the_value
    assert_equal "git", parser(%w[a --vcs git b]).take_flag("--vcs")
  end

  def test_take_flag_consumes_the_flag_and_its_value
    parser = parser(%w[a --vcs git b])

    parser.take_flag("--vcs")

    assert_equal %w[a b], parser.remaining
  end

  def test_take_flag_answers_a_value_written_with_an_equals_sign
    assert_equal "git", parser(%w[--vcs=git]).take_flag("--vcs")
  end

  def test_take_flag_consumes_only_the_equals_form_token
    parser = parser(%w[a --vcs=git b])

    parser.take_flag("--vcs")

    assert_equal %w[a b], parser.remaining
  end

  def test_take_flag_answers_nil_for_a_flag_without_a_value
    assert_nil parser(%w[a --vcs]).take_flag("--vcs")
  end

  def test_take_flag_leaves_a_flag_without_a_value_unconsumed
    parser = parser(%w[a --vcs])

    parser.take_flag("--vcs")

    assert_equal %w[a --vcs], parser.remaining
  end

  # The value is found by looking forward from the flag. Every command today puts
  # its value flag first, so nothing else notices if that lookup walks backwards.
  def test_take_flag_finds_its_value_when_another_flag_comes_first
    assert_equal "5", parser(%w[--contains --limit 5]).take_flag("--limit")
  end

  def test_take_flag_rejects_the_same_option_given_twice
    error = assert_raises(IntentRecord::ValidationError) { parser(%w[--vcs a --vcs b]).take_flag("--vcs") }

    assert_match(/--vcs given more than once/, error.message)
  end

  def test_take_integer_flag_defaults_when_absent
    assert_equal 7, parser([]).take_integer_flag("--limit", 7)
  end

  def test_take_integer_flag_accepts_the_equals_form
    assert_equal 5, parser(%w[--limit=5]).take_integer_flag("--limit", 9)
  end

  def test_take_integer_flag_rejects_non_digits
    assert_raises(IntentRecord::ValidationError) { parser(%w[--limit x]).take_integer_flag("--limit", 7) }
  end

  def test_take_required_positional_rejects_blank
    assert_raises(IntentRecord::ValidationError) { parser([" "]).take_required_positional("id") }
  end

  # `search` takes its terms from whatever is left after the options are lifted
  # out, and the options have to stay so that anything unrecognised is still
  # there to be rejected.
  def test_take_positionals_answers_the_terms
    assert_equal %w[retry backoff], parser(%w[retry backoff --bogus]).take_positionals
  end

  def test_take_positionals_leaves_the_options_unconsumed
    parser = parser(%w[retry backoff --bogus])

    parser.take_positionals

    assert_equal %w[--bogus], parser.remaining
  end

  def test_take_switch_reports_the_switch_and_consumes_it
    parser = parser(%w[a --contains])

    assert parser.take_switch?("--contains")
    assert_equal %w[a], parser.remaining
  end

  def test_take_switch_reports_an_absent_switch
    refute parser(%w[a]).take_switch?("--contains")
  end

  def test_reject_leftovers_names_what_it_did_not_understand
    error = assert_raises(IntentRecord::ValidationError) { parser(%w[--bogus extra]).reject_leftovers! }

    assert_match(/--bogus extra/, error.message)
  end

  def test_reject_leftovers_passes_when_everything_was_consumed
    assert_nil parser([]).reject_leftovers!
  end

  # Together these are what makes a dangling option an error rather than a
  # silently absent value: take_flag declines to consume it, so it is still
  # there when the leftovers are judged.
  def test_a_flag_left_without_its_value_survives_to_be_rejected
    parser = parser(%w[--vcs])

    assert_nil parser.take_flag("--vcs")
    assert_raises(IntentRecord::ValidationError) { parser.reject_leftovers! }
  end

  # The parser owns its arguments, so no caller can find its own array altered
  # by having asked a question about it.
  def test_the_array_it_was_built_from_is_never_altered
    argv = %w[a --vcs git b]

    parser(argv).take_flag("--vcs")

    assert_equal %w[a --vcs git b], argv
  end

  private

  def parser(argv)
    IntentRecord::CLI::ArgvParser.new(argv)
  end
end
