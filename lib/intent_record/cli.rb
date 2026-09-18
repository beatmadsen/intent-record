require "json"
require_relative "cli/streams"
require_relative "cli/argv_parser"
require_relative "cli/dispatch"

module IntentRecord
  # Entry point for the `intent-record` executable. JSON in, JSON out, exit 0 on success.
  class CLI
    CONFIG_DIR_FLAG = "--config-dir".freeze

    def self.run(argv)
      exit new(argv, config: Config.default, streams: Streams.default).run
    end

    def initialize(argv, config:, streams:)
      @argv = argv.dup
      @config = config
      @streams = streams
    end

    def run
      take_config_dir!
      dispatch(@argv.shift)
    rescue Error => e
      emit_error(e.message)
    end

    private

    # Lifted before the command is taken, so it may be written on either side of
    # it. A misspelling is left in argv, where it becomes an unknown command or an
    # unexpected argument: an option this CLI does not recognise is an error,
    # which an environment variable nobody set can never be.
    def take_config_dir!
      parser = ArgvParser.new(@argv)
      dir = parser.take_flag(CONFIG_DIR_FLAG)
      @argv = parser.remaining
      @config = Config.new(config_dir: dir) if dir
    end

    def dispatch(command)
      return usage if command.nil? || (@argv + [command]).intersect?(%w[--help -h])
      return version if %w[--version version].include?(command)

      connect!
      Dispatch.new(@argv, streams: @streams, config: @config).call(command)
    end

    def connect!
      @config.load!
      Database.connect!(@config.db_path)
    end

    def usage
      @streams.stderr.puts USAGE
      0
    end

    def version
      @streams.stdout.puts VERSION
      0
    end

    def emit_error(message)
      @streams.stdout.puts JSON.generate({ "error" => message })
      1
    end
  end
end
