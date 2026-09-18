require "test_helper"

# Adding a command means a `run_` method in Dispatch, a line in the usage text
# and a row in the README, and nothing until now noticed when only some of the
# three happened. A command missing from the usage is one nobody finds; a command
# advertised without a handler answers "Unknown command" to a person reading the
# help; and the README is where someone looks before installing anything.
class CommandsAndUsageTest < Minitest::Test
  ADVERTISED = IntentRecord::CLI::USAGE[/^Commands:\n(.*?)\n\n/m, 1].lines.map { |line| line.split.first }.sort.freeze
  README = File.expand_path("../../README.md", __dir__)
  # The first cell of each table row, taking the command out of `record` or
  # `lookup <commit> [--vcs name]`.
  DOCUMENTED = File.read(README).scan(/^\| `([a-z-]+)[^|]*\|/).flatten.sort.freeze

  def test_every_command_the_usage_advertises_has_a_handler
    assert_equal [], ADVERTISED - IntentRecord::CLI::Dispatch.commands,
                 "advertised in the usage text with nothing to run them"
  end

  def test_every_command_with_a_handler_is_advertised
    assert_equal [], IntentRecord::CLI::Dispatch.commands - ADVERTISED,
                 "runnable but absent from the usage text"
  end

  def test_every_command_with_a_handler_has_a_readme_row
    assert_equal [], IntentRecord::CLI::Dispatch.commands - DOCUMENTED,
                 "runnable but absent from the README command table"
  end

  def test_every_readme_row_names_a_command_that_exists
    assert_equal [], DOCUMENTED - IntentRecord::CLI::Dispatch.commands,
                 "in the README command table with nothing to run them"
  end
end
