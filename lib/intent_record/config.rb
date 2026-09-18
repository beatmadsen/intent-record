require "yaml"
require "fileutils"

module IntentRecord
  # Locates the config directory and the SQLite database path.
  # Bootstraps ~/.intent-record/config.yml on first use.
  class Config
    DEFAULT_CONFIG_DIR = File.expand_path("~/.intent-record")
    DB_FILENAME = "intent-record.db".freeze

    attr_reader :config_dir, :db_path

    def initialize(config_dir: nil)
      @config_dir = config_dir || ENV.fetch("INTENT_RECORD_CONFIG_DIR", DEFAULT_CONFIG_DIR)
    end

    def load!
      bootstrap! unless File.exist?(config_file_path)
      read_config!
      self
    end

    private

    def bootstrap!
      FileUtils.mkdir_p(@config_dir)
      File.write(config_file_path, YAML.dump("db_path" => File.join(@config_dir, DB_FILENAME)))
    end

    def config_file_path
      File.join(@config_dir, "config.yml")
    end

    def read_config!
      data = YAML.load_file(config_file_path)
      valid = data.is_a?(Hash) && !data["db_path"].to_s.strip.empty?
      raise ConfigError, "db_path is not configured in #{config_file_path}" unless valid

      @db_path = data["db_path"]
    end
  end
end
