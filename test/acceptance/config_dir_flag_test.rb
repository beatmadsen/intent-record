require "test_helper"

# The reason this flag exists: an environment variable that is not set looks
# exactly like one that is honoured, so a mistyped INTENT_RECORD_CONFIG_DIR sends
# a command at the store it was meant to stay away from and says nothing. A flag
# cannot fail that way, because argv this CLI does not recognise is refused.
class ConfigDirFlagTest < Minitest::Test
  include IntentRecordDsl

  def test_the_flag_puts_the_store_in_the_directory_it_names
    dir = temp_dir("config-dir-flag")

    run_cli_ok!("--config-dir", dir, "record", stdin: { "summary" => "s", "body" => "b" })

    assert_path_exists File.join(dir, "intent-record.db")
  end

  def test_the_flag_is_read_after_the_command_too
    dir = temp_dir("config-dir-flag")

    run_cli_ok!("record", "--config-dir", dir, stdin: { "summary" => "s", "body" => "b" })

    assert_path_exists File.join(dir, "intent-record.db")
  end

  def test_the_flag_accepts_the_equals_form
    dir = temp_dir("config-dir-flag")

    run_cli_ok!("--config-dir=#{dir}", "record", stdin: { "summary" => "s", "body" => "b" })

    assert_path_exists File.join(dir, "intent-record.db")
  end

  def test_a_command_run_through_the_flag_reads_back_its_own_store
    dir = temp_dir("config-dir-flag")
    id = run_cli_ok!("--config-dir", dir, "record", stdin: { "summary" => "only", "body" => "b" })["intent_id"]

    found = ids(run_cli_ok!("--config-dir", dir, "recent")["intents"])

    assert_equal [id], found
  end

  def ids(entries)
    entries.map { |entry| entry["intent_id"] }
  end

  # The point of the whole thing. A typo is argv nobody claimed, and argv nobody
  # claimed is an error.
  def test_a_mistyped_flag_is_refused_rather_than_ignored
    dir = temp_dir("config-dir-flag")

    assert_cli_rejected run_cli("--config-dri", dir, "record", stdin: { "summary" => "s", "body" => "b" }),
                        matching: [/Unknown option/, /--config-dri/]
  end

  def test_a_mistyped_flag_after_the_command_is_refused_too
    dir = temp_dir("config-dir-flag")

    assert_cli_rejected run_cli("record", "--config-dri", dir, stdin: { "summary" => "s", "body" => "b" }),
                        matching: /Unexpected argument/
  end

  def test_the_flag_without_a_directory_is_refused
    assert_cli_rejected run_cli("record", "--config-dir", stdin: { "summary" => "s", "body" => "b" }),
                        matching: /Unexpected argument/
  end

  def test_the_flag_given_twice_is_refused
    dir = temp_dir("config-dir-flag")

    assert_cli_rejected run_cli("--config-dir", dir, "--config-dir", dir, "recent"),
                        matching: /given more than once/
  end

  # Without the flag nothing changes: the config the caller handed in is used,
  # which is how every other test in the suite reaches its own store.
  def test_without_the_flag_the_given_config_is_used
    id = run_cli_ok!("record", stdin: { "summary" => "s", "body" => "b" })["intent_id"]

    assert_equal [id], ids(run_cli_ok!("recent")["intents"])
  end

  # The flag is a new way to name a store, so the confinement has to cover it.
  def test_the_flag_cannot_reach_the_production_store_from_a_test
    assert_raises(StoreConfinement::Escape) do
      run_cli("--config-dir", File.expand_path("~/.intent-record"), "recent")
    end
  end
end
