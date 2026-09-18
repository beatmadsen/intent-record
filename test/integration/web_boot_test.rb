require "test_helper"
require "minitest/mock"
require "intent_record/web/boot"

class WebBootTest < Minitest::Test
  include DbTestSetup

  # Really binding port 80 would pass for the wrong reason on a machine already
  # serving there, and could not run as root at all, so the bind is stubbed and
  # what is under test is the translation of its failure.
  def test_a_port_that_needs_privileges_is_reported_as_an_intent_record_error
    refuse_to_bind = ->(**) { raise Errno::EACCES, "bind(2) for 127.0.0.1 port 80" }

    error = IntentRecord::Web::App.stub(:run!, refuse_to_bind) do
      assert_raises(IntentRecord::Error) { boot(config, "--port", "80") }
    end

    assert_match(/privilege/i, error.message)
  end

  # Deliberately a different database from the one the harness connected, so the
  # assertion cannot pass on a connection run! did not make.
  # Removing what this test made means removing the path it made, never the path
  # Config resolved. Those are the same string right up until Config is wrong,
  # which is exactly when a test is running against somewhere that matters.
  def test_the_database_is_connected_before_the_server_starts
    dir = Dir.mktmpdir("intent-record-serve-")
    connected = nil
    record_connection = ->(**) { connected = ActiveRecord::Base.connection_db_config.database }

    IntentRecord::Web::App.stub(:run!, record_connection) do
      boot(IntentRecord::Config.new(config_dir: dir))
    end

    assert_equal File.join(dir, "intent-record.db"), connected
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_it_announces_the_address_it_is_serving_on
    IntentRecord::Web::App.stub(:run!, ->(**) {}) { boot(config, "--port", "4999") }

    assert_match(%r{http://127\.0\.0\.1:4999}, streams.stderr.string)
  end

  private

  def streams
    @streams ||= IntentRecord::CLI::Streams.new(stdin: StringIO.new, stdout: StringIO.new, stderr: StringIO.new)
  end

  def boot(config, *argv)
    IntentRecord::Web::Boot.run!(config: config, argv: argv, streams: streams)
  end
end
