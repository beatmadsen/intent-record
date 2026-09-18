require "test_helper"

class RecordValidationTest < Minitest::Test
  include IntentRecordDsl

  def test_rejects_missing_summary
    assert_cli_rejected run_cli("record", stdin: { "body" => "b" }), matching: /summary/
  end

  def test_rejects_blank_body
    assert_cli_rejected run_cli("record", stdin: { "summary" => "s", "body" => "  " }), matching: /body/
  end

  def test_rejects_invalid_json
    assert_cli_rejected run_cli("record", stdin: "{not json"), matching: /Invalid JSON/
  end

  def test_rejects_empty_stdin
    assert_cli_rejected run_cli("record", stdin: ""), matching: /Empty input/
  end

  def test_unknown_command_exits_one
    assert_cli_rejected run_cli("frobnicate"), matching: /Unknown command/
  end

  # A typo is the usual reason to land here, and the answer a person needs is
  # the name they meant to type.
  def test_an_unknown_command_names_the_commands_there_are
    assert_cli_rejected run_cli("frobnicate"), matching: /by-source/
  end
end
