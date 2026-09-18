require "test_helper"
require "intent_record/web/boot"

# serve was the one command whose argv never reached reject_leftovers!, because
# it forwards argv to Boot instead of going through Dispatch#finish!. It
# therefore accepted anything, and a mistyped --port started the server on the
# default port without saying so.
class BootArgvTest < Minitest::Test
  Boot = IntentRecord::Web::Boot

  def test_the_port_is_taken_from_the_option
    assert_equal 4999, Boot.parse_argv(["--port", "4999"]).port
  end

  def test_the_port_defaults_when_the_option_is_absent
    assert_equal Boot::DEFAULT_PORT, Boot.parse_argv([]).port
  end

  def test_an_unknown_option_is_rejected
    assert_raises(IntentRecord::ValidationError) { Boot.parse_argv(["--bogus"]) }
  end

  def test_a_stray_positional_is_rejected
    assert_raises(IntentRecord::ValidationError) { Boot.parse_argv(["wat"]) }
  end

  def test_a_mistyped_port_option_is_named_rather_than_silently_defaulted
    error = assert_raises(IntentRecord::ValidationError) { Boot.parse_argv(["--prot", "4999"]) }

    assert_match(/--prot/, error.message)
  end

  # Asserting only that something was raised would pass on the leftovers error
  # too, which is the rival reading now that parse_argv rejects leftovers, so the
  # range message is named.
  def test_a_port_outside_the_range_is_rejected_as_a_range_error
    error = assert_raises(IntentRecord::ValidationError) { Boot.parse_argv(["--port", "65536"]) }

    assert_match(/must be between 1 and 65535/, error.message)
  end

  def test_the_caller_argv_is_left_alone
    argv = ["--port", "4999"]

    Boot.parse_argv(argv)

    assert_equal ["--port", "4999"], argv
  end
end
