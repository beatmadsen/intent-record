require "test_helper"

class ArgvHandlingTest < Minitest::Test
  include IntentRecordDsl

  def test_stdin_that_is_not_valid_utf8_is_a_json_error
    result = run_cli("record", stdin: "{\"summary\":\"bad \xFF\",\"body\":\"y\"}".b)

    assert_cli_rejected result, matching: /UTF-8/
  end

  def test_an_option_can_be_written_with_an_equals_sign
    3.times { record_intent! }

    assert_equal 2, run_cli_ok!("recent", "--limit=2")["intents"].size
  end

  def test_the_same_option_twice_is_rejected
    assert_cli_rejected run_cli("search", "x", "--match", "all", "--match", "all"),
                        matching: /--match given more than once/
  end

  def test_an_unknown_option_is_rejected
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("show", id, "--bogus"), matching: /Unexpected argument/
  end

  def test_an_extra_positional_is_rejected
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("show", id, "extra"), matching: /Unexpected argument/
  end

  def test_an_option_left_without_its_value_is_rejected
    assert_cli_rejected run_cli("lookup", "1111", "--vcs"), matching: /Unexpected argument/
  end

  def test_an_argument_to_a_command_that_takes_none_is_rejected
    assert_cli_rejected run_cli("systems", "extra"), matching: /Unexpected argument/
  end

  def test_help_after_a_subcommand_prints_usage
    result = run_cli("show", "--help")

    assert result.success?
    assert_match(/Usage: intent-record/, result.stderr)
  end
end
