require "test_helper"
require "minitest/mock"
require "intent_record/web/boot"

# One test per command was how serve came to accept anything: the guard was
# written for the command someone happened to think of, and serve reaches its
# argv through Boot rather than Dispatch#finish!. This asks every command.
class UnknownArgvTest < Minitest::Test
  include IntentRecordDsl

  HASH = "1111111111111111111111111111111111111111".freeze

  # Enough valid argv to get each command past its own required positionals, so
  # that what it reports is the unknown option rather than a missing argument.
  ARGUMENTS = {
    "attach" => %w[zzzzzzz],
    "by-source" => %w[https://example.test/1],
    "lookup" => [HASH],
    "recent" => [],
    "record" => [],
    "search" => %w[term],
    "serve" => [],
    "show" => %w[zzzzzzz],
    "systems" => []
  }.freeze

  def test_every_command_has_an_argv_shape_here
    assert_equal IntentRecord::CLI::Dispatch.commands, ARGUMENTS.keys.sort,
                 "a command with no line here would not be asked about unknown argv"
  end

  def test_every_command_rejects_an_unknown_option
    assert_empty accepting("--bogus"), "accepted an unknown option instead of reporting it"
  end

  # search takes as many terms as it is given, so a further positional is another
  # term and not a mistake. SearchTest#test_search_match_all_requires_every_term
  # is what holds that up; this exclusion is not self-justifying.
  VARIADIC = %w[search].freeze

  def test_every_command_with_a_fixed_argument_count_rejects_a_stray_positional
    assert_empty accepting("stray", ARGUMENTS.except(*VARIADIC)),
                 "accepted a stray positional instead of reporting it"
  end

  private

  def accepting(token, commands = ARGUMENTS)
    commands.reject { |command, args| rejects?(command, args + [token]) }.keys
  end

  # serve is asked the same question as the others, so the bind is stubbed for
  # every command rather than for the one that needs it. Without this the test
  # only avoids starting a real server while the rejection it checks for works,
  # which is precisely the condition it is here to stop relying on.
  def rejects?(command, argv)
    result = IntentRecord::Web::App.stub(:run!, ->(**) {}) { run_cli(command, *argv) }
    !result.success? && /Unexpected argument/.match?(result.error_message)
  end
end
