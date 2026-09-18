require "json"
require_relative "cli/streams"
require_relative "cli/argv_parser"
require_relative "cli/dispatch"

module IntentRecord
  # Entry point for the `intent-record` executable. JSON in, JSON out, exit 0 on success.
  class CLI
    def self.run(argv)
      exit new(argv, config: Config.new, streams: Streams.default).run
    end

    def initialize(argv, config:, streams:)
      @argv = argv.dup
      @config = config
      @streams = streams
    end

    def run
      command = @argv.shift
      return usage if command.nil? || %w[--help -h].include?(command)
      return version if %w[--version version].include?(command)

      connect!
      Dispatch.new(@argv, streams: @streams, config: @config).call(command)
    rescue Error => e
      emit_error(e.message)
    end

    private

    def connect!
      @config.load!
      Database.connect!(@config.db_path)
    end

    def usage
      @streams.stderr.puts Dispatch::USAGE
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
