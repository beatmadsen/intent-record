require "json"
require_relative "argv_parser"
require_relative "../commands/record"
require_relative "../commands/show"

module IntentRecord
  class CLI
    # Maps a command name to the command object that handles it and prints its JSON result.
    class Dispatch
      USAGE = <<~USAGE.freeze
        Usage: intent-record <command> [options]

        Commands:
          record                     Record the intent behind a change (JSON via stdin)
          show <intent_id>           Full intent record with commits and stakeholder links

        Options:
          --help, -h                 Show this help
          --version                  Show version
      USAGE

      def initialize(argv, streams:, config:)
        @argv = argv
        @streams = streams
        @config = config
      end

      def call(command)
        handler = method_for(command)
        raise ValidationError, "Unknown command: #{command}" unless handler

        emit(send(handler))
      end

      private

      def method_for(command)
        name = "run_#{command.tr("-", "_")}"
        respond_to?(name, true) && name.start_with?("run_") ? name : nil
      end

      def emit(result)
        @streams.stdout.puts JSON.generate(result)
        0
      end

      def stdin_json
        ArgvParser.read_stdin_json(@streams.stdin)
      end

      def positional(label)
        ArgvParser.take_required_positional(@argv, label)
      end

      def run_record
        Commands::Record.new.call(stdin_json)
      end

      def run_show
        Commands::Show.new(intent_id: positional("intent_id")).call
      end
    end
  end
end
