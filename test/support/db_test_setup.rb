require "fileutils"
require "tmpdir"
require "yaml"

# Per-test tmpdir with a config.yml pointing at a fresh SQLite db.
module DbTestSetup
  attr_reader :config_dir, :config

  def setup
    @config_dir = Dir.mktmpdir("intent-record-test-")
    @config = IntentRecord::Config.new(config_dir: @config_dir).load!
    IntentRecord::Database.connect!(@config.db_path)
    super
  end

  def teardown
    super
    IntentRecord::Database.disconnect!
    FileUtils.remove_entry(@config_dir) if @config_dir && File.exist?(@config_dir)
  end
end
