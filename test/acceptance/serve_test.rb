require "test_helper"
require "socket"
require "timeout"

# The only test that reaches `serve`, and so the only one that runs Web::Boot.run!
# at all. It takes the failure path on purpose: a successful boot blocks forever.
class ServeTest < Minitest::Test
  include IntentRecordDsl

  def test_a_port_already_in_use_is_reported_as_json
    blocker = TCPServer.new("127.0.0.1", 0)
    port = blocker.addr[1]

    result = quietly { Timeout.timeout(30) { run_cli("serve", "--port", port.to_s) } }

    assert_cli_rejected result, matching: /already in use/
  ensure
    blocker&.close
  end

  private

  # Puma and Sinatra announce themselves on the real process streams, which the
  # injected ones do not cover.
  def quietly
    original_out = $stdout
    original_err = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = original_out
    $stderr = original_err
  end
end
