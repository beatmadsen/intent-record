require "tmpdir"

# Pointing Config's fallbacks at a sandbox made the production store unused. It
# was still reachable: any caller naming an absolute path got there, and reading
# it needed no config at all. This confines a test process to the temporary
# directory instead, and checks the path actually being opened rather than the
# route taken to it, so there is no spelling of the production store that works.
module StoreConfinement
  ROOT = File.realpath(Dir.tmpdir)

  class Escape < StandardError; end

  def self.confined?(path)
    resolved(path).start_with?("#{ROOT}/")
  end

  def self.check!(path, what)
    return if confined?(path)

    raise Escape, "refusing to open #{what} #{path}: a test may only use #{ROOT}"
  end

  # Dir.tmpdir is a symlink on macOS, so a path under it does not begin with the
  # resolved root until the part of it that exists has been resolved too. The
  # path itself need not exist: it is usually the database about to be created.
  def self.resolved(path)
    absolute = File.expand_path(path)
    existing = absolute
    existing = File.dirname(existing) until File.exist?(existing) || existing == File.dirname(existing)
    File.join(File.realpath(existing), absolute.delete_prefix(existing))
  end
end

# Three doors, because each is reachable without the other two: the app opens a
# store through Config and Database, and a test reading one directly needs
# neither. SQLite3::Database is the door every read also goes through.
module StoreConfinement
  module ConfigGuard
    def initialize(config_dir:)
      StoreConfinement.check!(config_dir, "config directory") unless config_dir.nil?
      super
    end
  end

  module DatabaseGuard
    def connect!(db_path)
      StoreConfinement.check!(db_path, "database")
      super
    end
  end

  module Sqlite3Guard
    def initialize(file, *, **, &)
      StoreConfinement.check!(file, "sqlite database") if file.is_a?(String)
      super
    end
  end
end

module StoreConfinement
  def self.installed?
    IntentRecord::Config.ancestors.include?(ConfigGuard) &&
      IntentRecord::Database.singleton_class.ancestors.include?(DatabaseGuard) &&
      SQLite3::Database.ancestors.include?(Sqlite3Guard)
  end

  # Checked before every test body rather than once at load, so a guard that is
  # gone stops the suite where it can be reported as a failure. The confinement
  # is the only thing standing between the suite and the author's records, and an
  # unverified guard licenses exactly the belief that let this happen once.
  module Guard
    def before_setup
      super
      return if StoreConfinement.installed?

      flunk "store confinement is not installed, so a test could reach the production store"
    end
  end
end

IntentRecord::Config.prepend(StoreConfinement::ConfigGuard)
IntentRecord::Database.singleton_class.prepend(StoreConfinement::DatabaseGuard)
SQLite3::Database.prepend(StoreConfinement::Sqlite3Guard)
Minitest::Test.include(StoreConfinement::Guard)
