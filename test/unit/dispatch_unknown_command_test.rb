require "test_helper"

# A typo is the usual reason to reach here, so the answer a person needs is the
# name they meant to type. The list is taken from the handlers rather than
# written out, so it cannot fall behind what the dispatch answers to.
class DispatchUnknownCommandTest < Minitest::Test
  def test_an_unknown_command_is_rejected
    assert_raises(IntentRecord::ValidationError) { dispatch.call("frobnicate") }
  end

  def test_the_refusal_names_the_command_that_was_not_understood
    assert_match(/frobnicate/, refusal.message)
  end

  def test_the_refusal_lists_every_command_there_is
    listed = refusal.message[/Known commands: (.*)\z/, 1].split(", ")

    assert_equal IntentRecord::CLI::Dispatch.commands, listed
  end

  private

  def refusal
    assert_raises(IntentRecord::ValidationError) { dispatch.call("frobnicate") }
  end

  def dispatch
    streams = IntentRecord::CLI::Streams.new(stdin: StringIO.new, stdout: StringIO.new, stderr: StringIO.new)
    IntentRecord::CLI::Dispatch.new([], streams: streams, config: nil)
  end
end
