require "active_record"
require "active_record/connection_adapters/sqlite3_adapter"

module IntentRecord
  # Applied to every pooled SQLite connection: pragmas, and a Unicode-aware ULOWER() so
  # case-insensitive search works for non-ASCII letters (SQLite's LOWER folds ASCII only).
  module SqliteConnectionSetup
    PRAGMAS = ["PRAGMA foreign_keys = ON", "PRAGMA journal_mode = WAL", "PRAGMA busy_timeout = 5000"].freeze

    def configure_connection
      super
      PRAGMAS.each { |sql| @raw_connection.execute(sql) }
      @raw_connection.create_function("ulower", 1) do |fn, value|
        fn.result = value&.to_s&.downcase
      end
    end
  end

  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteConnectionSetup)
end
