require "test_helper"
require "minitest/mock"
require "intent_record/web/boot"

# Binding a privileged port is a plausible mistake, but a test that really tried
# port 80 would pass for the wrong reason on a machine already serving there, and
# not at all as root. Stub the bind instead and check the translation.
class WebBootTest < Minitest::Test
  include DbTestSetup

  def test_a_port_that_needs_privileges_is_reported_as_an_intent_record_error
    error = IntentRecord::Web::App.stub(:run!, ->(**) { raise Errno::EACCES, "bind(2) for 127.0.0.1 port 80" }) do
      assert_raises(IntentRecord::Error) do
        without_stderr { IntentRecord::Web::Boot.run!(config: config, argv: %w[--port 80]) }
      end
    end

    assert_match(/privilege/i, error.message)
  end

  private

  # run! announces the address it is about to serve on before it binds.
  def without_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end
end
