require "active_record"
require "fileutils"
require "sqlite3"
require_relative "seeds"
require_relative "sqlite_connection_setup"

module IntentRecord
  module Database
    MIGRATIONS_PATH = File.expand_path("../../db/migrate", __dir__)

    # mkdir_p raises an Errno when the parent cannot be created, but once the
    # directory exists sqlite reports an unwritable file or directory through
    # ActiveRecord instead, so both families have to become the same DatabaseError.
    UNWRITABLE_CAUSES = [SQLite3::CantOpenException, SQLite3::ReadOnlyException].freeze

    def self.connect!(db_path)
      FileUtils.mkdir_p(File.dirname(db_path))
      ActiveRecord::Base.logger = nil
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: db_path)
      run_migrations!
      Seeds.apply!
    rescue Errno::EACCES, Errno::EPERM, Errno::EROFS => e
      raise DatabaseError, unwritable(db_path, e)
    rescue ActiveRecord::StatementInvalid => e
      raise unless UNWRITABLE_CAUSES.any? { |klass| e.cause.is_a?(klass) }

      raise DatabaseError, unwritable(db_path, e.cause)
    end

    def self.unwritable(db_path, error)
      "Database path is not writable: #{db_path} (#{error.message})"
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
