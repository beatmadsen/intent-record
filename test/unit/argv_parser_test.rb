require "test_helper"

class ArgvParserTest < Minitest::Test
  Parser = IntentRecord::CLI::ArgvParser

  def test_take_flag_answers_the_value
    assert_equal "git", Parser.take_flag(%w[a --vcs git b], "--vcs")
  end

  def test_take_flag_removes_the_flag_and_its_value_from_argv
    argv = %w[a --vcs git b]

    Parser.take_flag(argv, "--vcs")

    assert_equal %w[a b], argv
  end

  def test_take_flag_answers_a_value_written_with_an_equals_sign
    assert_equal "git", Parser.take_flag(%w[--vcs=git], "--vcs")
  end

  def test_take_flag_removes_only_the_equals_form_token
    argv = %w[a --vcs=git b]

    Parser.take_flag(argv, "--vcs")

    assert_equal %w[a b], argv
  end

  def test_take_integer_flag_accepts_the_equals_form
    assert_equal 5, Parser.take_integer_flag(%w[--limit=5], "--limit", 9)
  end

  def test_take_flag_rejects_the_same_option_given_twice
    error = assert_raises(IntentRecord::ValidationError) { Parser.take_flag(%w[--vcs a --vcs b], "--vcs") }

    assert_match(/--vcs given more than once/, error.message)
  end

  def test_take_flag_without_value_returns_nil_and_leaves_argv
    argv = %w[a --vcs]

    assert_nil Parser.take_flag(argv, "--vcs")
    assert_equal %w[a --vcs], argv
  end

  # The value is found by looking forward from the flag. Every command today puts
  # its value flag first, so nothing else notices if that lookup walks backwards.
  def test_take_flag_finds_its_value_when_another_flag_comes_first
    argv = %w[--contains --limit 5]

    assert_equal "5", Parser.take_flag(argv, "--limit")
    assert_equal %w[--contains], argv
  end

  def test_take_integer_flag_defaults_when_absent
    assert_equal 7, Parser.take_integer_flag([], "--limit", 7)
  end

  def test_take_integer_flag_rejects_non_digits
    assert_raises(IntentRecord::ValidationError) { Parser.take_integer_flag(%w[--limit x], "--limit", 7) }
  end

  def test_take_required_positional_rejects_blank
    assert_raises(IntentRecord::ValidationError) { Parser.take_required_positional([" "], "id") }
  end

  # `search` takes its terms from whatever is left after the options are lifted
  # out, and the options have to stay in argv so that anything unrecognised is
  # still there to be rejected.
  def test_take_positionals_removes_the_terms_and_leaves_the_options_behind
    argv = %w[retry backoff --bogus]

    assert_equal %w[retry backoff], Parser.take_positionals(argv)
    assert_equal %w[--bogus], argv
  end

  def test_take_switch_reports_the_switch_and_removes_it
    argv = %w[a --contains]

    assert Parser.take_switch?(argv, "--contains")
    assert_equal %w[a], argv
  end

  def test_take_switch_reports_an_absent_switch
    refute Parser.take_switch?(%w[a], "--contains")
  end

  def test_reject_leftovers_names_what_it_did_not_understand
    error = assert_raises(IntentRecord::ValidationError) { Parser.reject_leftovers!(%w[--bogus extra]) }

    assert_match(/--bogus extra/, error.message)
  end

  def test_reject_leftovers_passes_an_empty_argv
    assert_nil Parser.reject_leftovers!([])
  end

  # The two together are what makes a dangling option an error rather than a
  # silently absent value: take_flag declines to consume it, so it is still there
  # when the leftovers are judged.
  def test_a_flag_left_without_its_value_survives_to_be_rejected
    argv = %w[--vcs]

    assert_nil Parser.take_flag(argv, "--vcs")
    assert_raises(IntentRecord::ValidationError) { Parser.reject_leftovers!(argv) }
  end

  def test_read_stdin_json_rejects_non_object
    assert_raises(IntentRecord::ValidationError) { Parser.read_stdin_json(StringIO.new("[1]")) }
  end

  def test_read_stdin_json_rejects_input_that_is_not_valid_utf8
    error = assert_raises(IntentRecord::ValidationError) do
      Parser.read_stdin_json(StringIO.new(%({"summary":"bad \xFF"}).b))
    end

    assert_match(/UTF-8/, error.message)
  end
end
