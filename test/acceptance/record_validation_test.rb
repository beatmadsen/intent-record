require "test_helper"

class RecordValidationTest < Minitest::Test
  include IntentRecordDsl

  # StdinJson's own rules (empty input, malformed JSON, invalid UTF-8) are pinned
  # at StdinJsonTest. What these two are here for is which fields `record`
  # demands, which is a property of the command rather than of the validator.
  def test_the_summary_is_required
    assert_cli_rejected run_cli("record", stdin: { "body" => "b" }), matching: /summary is required/
  end

  def test_the_body_is_required
    assert_cli_rejected run_cli("record", stdin: { "summary" => "s" }), matching: /body is required/
  end
end
