require "test_helper"

# Config is the only thing that writes outside the database, and on a real first
# run it writes into a directory that does not exist yet.
class ConfigTest < Minitest::Test
  def setup
    @root = temp_dir("config")
  end

  # The store a person keeps their own records in is reachable only by asking for
  # it by name. A caller that loses the argument gets an error, not somebody's
  # home directory, which is how a test run came to delete one.
  def test_a_config_must_be_told_which_directory_it_is_for
    assert_raises(ArgumentError) { IntentRecord::Config.new }
  end

  def test_a_nil_directory_is_refused_rather_than_filled_in
    assert_raises(ArgumentError) { IntentRecord::Config.new(config_dir: nil) }
  end

  def test_load_creates_a_config_directory_that_does_not_exist_yet
    dir = File.join(@root, "never", "created")

    IntentRecord::Config.new(config_dir: dir).load!

    assert File.exist?(File.join(dir, "config.yml"))
  end

  def test_a_bootstrapped_config_points_at_a_database_inside_the_config_directory
    config = IntentRecord::Config.new(config_dir: @root).load!

    assert_equal File.join(@root, "intent-record.db"), config.db_path
  end

  def test_a_blank_db_path_is_rejected
    write_config("db_path" => "   ")

    error = assert_raises(IntentRecord::ConfigError) { IntentRecord::Config.new(config_dir: @root).load! }
    assert_match(/db_path is not configured/, error.message)
  end

  def test_a_config_file_that_is_not_a_mapping_is_rejected
    File.write(File.join(@root, "config.yml"), "just a string\n")

    assert_raises(IntentRecord::ConfigError) { IntentRecord::Config.new(config_dir: @root).load! }
  end

  private

  def write_config(data)
    File.write(File.join(@root, "config.yml"), YAML.dump(data))
  end
end
