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

    # A failed bind returns in well under a second. The guard is here so that a
    # change which makes serve ignore --port, and so really start a server, fails
    # this test instead of hanging the run; it has to fire well before the
    # mutation lane's own per-mutant timeout, or that is what gives out first.
    result = quietly { Timeout.timeout(5) { run_cli("serve", "--port", port.to_s) } }

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
