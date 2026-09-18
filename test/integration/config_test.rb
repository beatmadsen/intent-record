require "test_helper"

# Config is the only thing that writes outside the database, and on a real first
# run it writes into a directory that does not exist yet.
class ConfigTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("intent-record-config-")
  end

  def teardown
    FileUtils.rm_rf(@root)
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
