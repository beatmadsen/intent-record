require "active_record"
require "fileutils"
require_relative "seeds"
require_relative "sqlite_connection_setup"

module IntentRecord
  module Database
    MIGRATIONS_PATH = File.expand_path("../../db/migrate", __dir__)

    def self.connect!(db_path)
      FileUtils.mkdir_p(File.dirname(db_path))
      ActiveRecord::Base.logger = nil
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: db_path)
      run_migrations!
      Seeds.apply!
    rescue Errno::EACCES, Errno::EPERM, Errno::EROFS => e
      raise DatabaseError, "Database path is not writable: #{db_path} (#{e.message})"
    end

    def self.disconnect!
      ActiveRecord::Base.remove_connection
    rescue StandardError
      nil
    end

    def self.run_migrations!
      ActiveRecord::Migration.verbose = false
      ActiveRecord::MigrationContext.new(MIGRATIONS_PATH).migrate
    end
  end
end
