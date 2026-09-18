require "active_record"
require "fileutils"

module IntentRecord
  module Database
    MIGRATIONS_PATH = File.expand_path("../../db/migrate", __dir__)

    def self.connect!(db_path)
      prepare_directory!(db_path)
      ActiveRecord::Base.logger = nil
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: db_path)
      apply_pragmas!
      run_migrations!
    rescue Errno::EACCES, Errno::EPERM, Errno::EROFS => e
      raise DatabaseError, "Database path is not writable: #{db_path} (#{e.message})"
    end

    def self.disconnect!
      ActiveRecord::Base.remove_connection
    rescue StandardError
      nil
    end

    def self.prepare_directory!(db_path)
      FileUtils.mkdir_p(File.dirname(db_path))
    end

    def self.apply_pragmas!
      conn = ActiveRecord::Base.connection
      conn.execute("PRAGMA foreign_keys = ON")
      conn.execute("PRAGMA journal_mode = WAL")
      conn.execute("PRAGMA busy_timeout = 5000")
    end

    def self.run_migrations!
      ActiveRecord::Migration.verbose = false
      ActiveRecord::MigrationContext.new(MIGRATIONS_PATH).migrate
    end
  end
end
