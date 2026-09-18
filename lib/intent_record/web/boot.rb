require_relative "../config"
require_relative "../database"
require_relative "app"
require_relative "../cli/streams"

module IntentRecord
  module Web
    # Boots the GUI on localhost only. Connects (and migrates) the database first.
    module Boot
      BIND = "127.0.0.1".freeze
      DEFAULT_PORT = 4791
      PORT_RANGE = (1..65_535)

      Options = Struct.new(:port, keyword_init: true)

      module_function

      # Out of range, the bind fails with a resolution error that says nothing about
      # ports, so reject it here rather than let the socket layer explain it badly.
      # Leftovers are rejected here too, because serve forwards its argv straight
      # to Boot and so never passes through Dispatch#finish!.
      def parse_argv(argv)
        parser = CLI::ArgvParser.new(argv)
        port = parser.take_integer_flag("--port", DEFAULT_PORT)
        parser.reject_leftovers!
        raise ValidationError, "--port must be between #{PORT_RANGE.first} and #{PORT_RANGE.last}, got #{port}" \
          unless PORT_RANGE.cover?(port)

        Options.new(port: port)
      end

      def run!(config:, argv:, streams: CLI::Streams.default)
        port = parse_argv(argv).port
        config.load!
        Database.connect!(config.db_path)
        streams.stderr.puts "intent-record GUI on http://#{BIND}:#{port} (db: #{config.db_path})"
        serve!(port)
      end

      # Only the bind itself can refuse a port, and Database.connect! has already
      # translated its own permission failures, so these two reach here from App only.
      def serve!(port)
        App.run!(bind: BIND, port: port)
      rescue Errno::EADDRINUSE
        raise Error, "Port #{port} is already in use; pass --port to choose another"
      rescue Errno::EACCES
        raise Error, "Port #{port} needs elevated privileges; pass --port to choose another"
      end
    end
  end
end
