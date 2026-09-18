require "test_helper"
require "intent_record/web/boot"

class WebBootParseArgvTest < Minitest::Test
  def test_defaults_to_configured_port
    opts = IntentRecord::Web::Boot.parse_argv([])

    assert_equal IntentRecord::Web::Boot::DEFAULT_PORT, opts.port
  end

  def test_reads_port_flag
    assert_equal 5555, IntentRecord::Web::Boot.parse_argv(%w[--port 5555]).port
  end

  def test_rejects_non_integer_port
    assert_raises(IntentRecord::ValidationError) { IntentRecord::Web::Boot.parse_argv(%w[--port abc]) }
  end
end
