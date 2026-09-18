require "test_helper"
require "intent_record/web/boot"

# The historical failure this exists for: a test reached `serve` without
# stubbing the bind, started a real Puma, and hung the run until the process was
# found with lsof and killed. What it should do instead is fail, here, at once.
class PortConfinementTest < Minitest::Test
  include IntentRecordDsl

  def test_the_confinement_is_installed
    assert PortConfinement.installed?
  end

  def test_binding_a_port_is_refused
    assert_raises(PortConfinement::Escape) { TCPServer.new("127.0.0.1", 0) }
  end

  def test_the_refusal_says_what_to_do_instead
    error = assert_raises(PortConfinement::Escape) { TCPServer.new("127.0.0.1", 0) }

    assert_match(/stub/i, error.message)
  end

  # The real shape of the mistake: no stub on App.run!, so the boot reaches the
  # bind. Refused rather than served.
  #
  # capture_io because Sinatra and Puma announce themselves on the way to a bind
  # that is about to be refused, and a suite that prints "taken the stage on
  # 4791" while proving nothing is listening is the misleading signal this whole
  # guard exists to remove.
  def test_serving_for_real_without_a_stub_is_refused_rather_than_started
    assert_raises(PortConfinement::Escape) { capture_io { boot("--port", "4791") } }
  end

  def test_a_deliberate_bind_is_allowed_when_a_test_says_so
    server = PortConfinement.binding_a_port { TCPServer.new("127.0.0.1", 0) }

    assert_predicate server.addr[1], :positive?
  ensure
    server&.close
  end

  # The allowance is undone afterwards, so one test cannot leave binding open for
  # whatever runs next in the same process.
  def test_the_allowance_does_not_outlive_its_block
    PortConfinement.binding_a_port { nil }

    assert_raises(PortConfinement::Escape) { TCPServer.new("127.0.0.1", 0) }
  end

  private

  def boot(*argv)
    IntentRecord::Web::Boot.run!(config: config, argv: argv, streams: streams)
  end

  def streams
    @streams ||= IntentRecord::CLI::Streams.new(stdin: StringIO.new, stdout: StringIO.new, stderr: StringIO.new)
  end
end
