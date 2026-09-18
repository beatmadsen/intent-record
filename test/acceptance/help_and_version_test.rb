require "test_helper"

# --help and --version return before the database is touched, and --help is
# honoured wherever it appears, which is why it is checked after a command too.
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

  # Not a bare form: the command has already been shifted off, so this is the
  # only case where the flag has to be found in what is left of argv.
  def test_help_after_a_command_prints_usage_instead_of_running_it
    result = run_cli("show", "--help")

    assert_equal 0, result.exit_code
    assert_match(/Usage: intent-record/, result.stderr)
  end

  def test_the_version_command_prints_the_gem_version
    assert_equal IntentRecord::VERSION, run_cli("version").stdout.strip
  end

  def test_the_version_flag_prints_the_gem_version
    assert_equal IntentRecord::VERSION, run_cli("--version").stdout.strip
  end
end
