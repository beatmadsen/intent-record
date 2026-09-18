require "test_helper"

# The bare forms, where the flag arrives as the command itself rather than after
# one. Both return before the database is touched.
class HelpAndVersionTest < Minitest::Test
  include IntentRecordDsl

  def test_help_on_its_own_prints_usage_to_stderr
    result = run_cli("--help")

    assert_equal 0, result.exit_code
    assert_match(/Usage: intent-record/, result.stderr)
  end

  def test_short_help_on_its_own_prints_usage_to_stderr
    assert_match(/Usage: intent-record/, run_cli("-h").stderr)
  end

  def test_the_version_command_prints_the_gem_version
    assert_equal IntentRecord::VERSION, run_cli("version").stdout.strip
  end

  def test_the_version_flag_prints_the_gem_version
    assert_equal IntentRecord::VERSION, run_cli("--version").stdout.strip
  end
end
