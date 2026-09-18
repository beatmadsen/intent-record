require "test_helper"

# Adding a command means a `run_` method in Dispatch and a line in the usage
# text, and nothing until now noticed when only one of the two happened. A
# command missing from the usage is one nobody finds; a command advertised
# without a handler answers "Unknown command" to a person reading the help.
class CommandsAndUsageTest < Minitest::Test
  ADVERTISED = IntentRecord::CLI::USAGE[/^Commands:\n(.*?)\n\n/m, 1].lines.map { |line| line.split.first }.sort.freeze

  def test_every_command_the_usage_advertises_has_a_handler
    assert_equal [], ADVERTISED - IntentRecord::CLI::Dispatch.commands,
                 "advertised in the usage text with nothing to run them"
  end

  def test_every_command_with_a_handler_is_advertised
    assert_equal [], IntentRecord::CLI::Dispatch.commands - ADVERTISED,
                 "runnable but absent from the usage text"
  end
end
