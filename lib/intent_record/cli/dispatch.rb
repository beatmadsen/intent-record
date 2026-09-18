require "json"
require_relative "argv_parser"
require_relative "usage"
require_relative "../commands/record"
require_relative "../commands/show"
require_relative "../commands/lookup"
require_relative "../commands/search"
require_relative "../commands/by_source"
require_relative "../commands/recent"
require_relative "../commands/attach"
require_relative "../commands/systems"

module IntentRecord
  class CLI
    # Maps a command name to the command object that handles it and prints its JSON result.
    # Each run_* parses argv fully, then `finish!` rejects anything left over before running.
    class Dispatch
      def initialize(argv, streams:, config:)
        @argv = argv
        @streams = streams
        @config = config
      end

      def call(command)
        handler = "run_#{command.to_s.tr("-", "_")}"
        raise ValidationError, "Unknown command: #{command}" unless respond_to?(handler, true)

        emit(send(handler))
      end

      private

      def emit(result)
        @streams.stdout.puts JSON.generate(result)
        0
      end

      def finish!
        ArgvParser.reject_leftovers!(@argv)
        yield
      end

      def stdin_json
        ArgvParser.read_stdin_json(@streams.stdin)
      end

      def positional(label)
        ArgvParser.take_required_positional(@argv, label)
      end

      def run_record
        finish! { Commands::Record.new.call(stdin_json) }
      end

      def run_show
        command = Commands::Show.new(intent_id: positional("intent_id"))
        finish! { command.call }
      end

      def run_lookup
        vcs = ArgvParser.take_flag(@argv, "--vcs")
        command = Commands::Lookup.new(external_id: positional("external_id"), vcs: vcs)
        finish! { command.call }
      end

      def run_search
        match = ArgvParser.take_flag(@argv, "--match") || "any"
        options, terms = @argv.partition { |a| a.start_with?("--") }
        @argv.replace(options)
        finish! { Commands::Search.new(terms: terms, match: match).call }
      end

      def run_by_source
        contains = ArgvParser.take_switch?(@argv, "--contains")
        command = Commands::BySource.new(uri: positional("uri"), contains: contains)
        finish! { command.call }
      end

      def run_recent
        limit = ArgvParser.take_integer_flag(@argv, "--limit", Commands::Recent::DEFAULT_LIMIT)
        finish! { Commands::Recent.new(limit: limit).call }
      end

      def run_attach
        command = Commands::Attach.new(intent_id: positional("intent_id"))
        finish! { command.call(stdin_json) }
      end

      def run_systems
        finish! { Commands::Systems.new.call }
      end

      def run_serve
        require_relative "../web/boot"
        Web::Boot.run!(config: @config, argv: @argv, streams: @streams)
        {}
      end
    end
  end
end
