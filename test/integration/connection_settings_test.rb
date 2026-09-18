require "test_helper"

class ConnectionSettingsTest < Minitest::Test
  include DbTestSetup

  # ActiveRecord installs no busy handler unless the connection is given a
  # :timeout; its own documentation says the default is no wait. Our pragma sets
  # sqlite's timeout, which is a different thing, and a passing pragma test was
  # not evidence that a concurrent write would wait. Assert the adapter got it.
  def test_the_connection_is_told_how_long_to_wait_for_a_busy_database
    configured = ActiveRecord::Base.connection_db_config.configuration_hash[:timeout]

    assert_equal IntentRecord::SqliteConnectionSetup::BUSY_TIMEOUT_MS, configured
  end
end
