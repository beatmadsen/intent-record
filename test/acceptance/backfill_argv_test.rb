require "test_helper"

# What `backfill` refuses before it reads a payload. Argv is judged first, so
# none of these needs a history to be given one.
class BackfillArgvTest < Minitest::Test
  include IntentRecordDsl

  PATTERN = 'ACME-\d+'.freeze

  def test_a_backfill_without_a_system_is_refused
    assert_cli_rejected run_cli("backfill", "--pattern", PATTERN), matching: /--system/
  end

  def test_a_backfill_without_a_pattern_is_refused
    assert_cli_rejected run_cli("backfill", "--system", "jira"), matching: /--pattern/
  end

  def test_an_order_the_command_does_not_know_is_refused
    result = run_cli("backfill", "--system", "jira", "--pattern", PATTERN, "--order", "sideways")

    assert_cli_rejected result, matching: /--order/
  end

  def test_a_pattern_that_is_not_a_regular_expression_is_refused
    result = run_cli("backfill", "--system", "jira", "--pattern", "ACME-[")

    assert_cli_rejected result, matching: /pattern/
  end
end
