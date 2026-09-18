require "test_helper"

class ArgvParserTest < Minitest::Test
  Parser = IntentRecord::CLI::ArgvParser

  def test_take_flag_removes_flag_and_value
    argv = %w[a --vcs git b]

    assert_equal "git", Parser.take_flag(argv, "--vcs")
    assert_equal %w[a b], argv
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

  def test_read_stdin_json_rejects_non_object
    assert_raises(IntentRecord::ValidationError) { Parser.read_stdin_json(StringIO.new("[1]")) }
  end
end
