require "json"
require_relative "argv_parser"
require_relative "stdin_json"
require_relative "usage"
require_relative "../commands/record"
require_relative "../commands/show"
require_relative "../commands/lookup"
require_relative "../commands/search"
require_relative "../commands/by_source"
require_relative "../commands/recent"
require_relative "../commands/attach"
require_relative "../commands/systems"
require_relative "../commands/backfill"
require_relative "../commands/blame"
require_relative "blame_input"

module IntentRecord
  class CLI
    # Maps a command name to the command object that handles it and prints its JSON result.
    # Each run_* parses argv fully, then `finish!` rejects anything left over before running.
    class Dispatch
      HANDLER_PREFIX = "run_".freeze

      # The commands there are, taken from the handlers that implement them, so
      # the list cannot fall behind what the dispatch actually answers to.
      def self.commands
        handlers = private_instance_methods(false).grep(/\A#{HANDLER_PREFIX}/)
        handlers.map { |name| name.to_s.delete_prefix(HANDLER_PREFIX).tr("_", "-") }.sort
      end

      def initialize(argv, streams:, config:)
        @parser = ArgvParser.new(argv)
        @streams = streams
        @config = config
      end

      def call(command)
        handler = "#{HANDLER_PREFIX}#{command.to_s.tr("-", "_")}"
        raise ValidationError, unknown(command) unless respond_to?(handler, true)

        emit(send(handler))
      end

      private

      # An option in the command's place is almost always a misspelled one, and
      # calling it an unknown command sends the reader looking for a command they
      # never meant to type.
      def unknown(command)
        return "Unknown option: #{command}" if command.to_s.start_with?("--")

        "Unknown command: #{command}. Known commands: #{self.class.commands.join(", ")}"
      end

      def emit(result)
        @streams.stdout.puts JSON.generate(result)
        0
      end

      def finish!
        @parser.reject_leftovers!
        yield
      end

      def stdin_json
        StdinJson.read(@streams.stdin)
      end

      def positional(label)
        @parser.take_required_positional(label)
      end

      def required_flag(name)
        value = @parser.take_flag(name)
        raise ValidationError, "#{name} is required" if value.nil? || value.strip.empty?

        value
      end

      def run_record
        finish! { Commands::Record.new.call(stdin_json) }
      end

      def run_show
        command = Commands::Show.new(intent_id: positional("intent_id"))
        finish! { command.call }
      end

      def run_lookup
        vcs = @parser.take_flag("--vcs")
        command = Commands::Lookup.new(external_id: positional("external_id"), vcs: vcs)
        finish! { command.call }
      end

      def run_search
        match = @parser.take_flag("--match") || "any"
        terms = @parser.take_positionals
        finish! { Commands::Search.new(terms: terms, match: match).call }
      end

      def run_by_source
        contains = @parser.take_switch?("--contains")
        command = Commands::BySource.new(uri: positional("uri"), contains: contains)
        finish! { command.call }
      end

      def run_recent
        limit = @parser.take_integer_flag("--limit", Commands::Recent::DEFAULT_LIMIT)
        finish! { Commands::Recent.new(limit: limit).call }
      end

      def run_attach
        command = Commands::Attach.new(intent_id: positional("intent_id"))
        finish! { command.call(stdin_json) }
      end

      def run_backfill
        command = Commands::Backfill.scanning(system: required_flag("--system"),
                                              pattern: required_flag("--pattern"),
                                              uri_prefix: @parser.take_flag("--uri-prefix"),
                                              dry_run: @parser.take_switch?("--dry-run"),
                                              order: @parser.take_flag("--order") ||
                                           Commands::Backfill::DEFAULT_ORDER)
        finish! { command.call(stdin_json) }
      end

      def run_blame
        format = @parser.take_flag("--format")
        finish! { Commands::Blame.new.call(BlameInput.read(format, @streams.stdin)) }
      end

      def run_systems
        finish! { Commands::Systems.new.call }
      end

      def run_serve
        require_relative "../web/boot"
        Web::Boot.run!(config: @config, argv: @parser.remaining, streams: @streams)
        {}
      end
    end
  end
end
