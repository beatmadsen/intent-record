require "test_helper"

# Two processes reaching a new store together each find the tables missing and
# each create them, so setup is serialised on a lock file. Tested by asking
# whether the lock is held rather than by racing real processes: a race decides
# what it decides, and a test that only usually reproduces the bug only usually
# catches its return.
class DatabaseSetupLockTest < Minitest::Test
  def setup
    @db_path = File.join(temp_dir("setup-lock"), "x.db")
  end

  def test_the_lock_is_held_for_the_duration_of_setup
    held = nil

    IntentRecord::Database.while_setting_up(@db_path) { held = lock_available? }

    refute held, "another process could have migrated at the same time"
  end

  def test_the_lock_is_released_afterwards
    IntentRecord::Database.while_setting_up(@db_path) { nil }

    assert lock_available?, "the lock outlived setup and would block every later connect"
  end

  # A lock left behind by a failure is worse than no lock: every later connect
  # waits on it forever.
  def test_the_lock_is_released_when_setup_raises
    assert_raises(RuntimeError) do
      IntentRecord::Database.while_setting_up(@db_path) { raise "migration blew up" }
    end

    assert lock_available?
  end

  private

  # flock conflicts between file descriptions, so a second handle in this process
  # answers the same question a second process would ask.
  def lock_available?
    File.open("#{@db_path}.setup", File::RDWR | File::CREAT) do |probe|
      probe.flock(File::LOCK_EX | File::LOCK_NB) != false
    end
  end
end
