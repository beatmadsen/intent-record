require "test_helper"

# What each of these pins, measured by deleting the lines one at a time:
# busy_timeout is ours alone, and only its test goes red when the PRAGMAS line
# goes. Foreign keys and WAL are set twice over, by our pragmas and by the
# adapter's own configure_connection that `super` calls, so those two tests stay
# green if either mechanism is removed and only bite if both go. They are here
# for the invariant the README and CLAUDE.md state, not as proof of one line.
# All three ask SQLite what it is doing rather than reading the constant back.
class SqlitePragmasTest < Minitest::Test
  include DbTestSetup

  def test_foreign_keys_are_enforced
    assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.execute(<<~SQL)
        INSERT INTO stakeholder_sources (stakeholder_system_id, uri, created_at)
        VALUES (987654321, 'https://acme.example/orphan', '2026-01-01 00:00:00')
      SQL
    end
  end

  def test_the_journal_is_in_wal_mode
    assert_equal "wal", connection.select_value("PRAGMA journal_mode")
  end

  def test_a_busy_connection_waits_before_giving_up
    assert_equal 5000, connection.select_value("PRAGMA busy_timeout")
  end

  private

  def connection
    ActiveRecord::Base.connection
  end
end
