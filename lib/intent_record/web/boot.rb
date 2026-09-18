require_relative "../config"
require_relative "../database"
require_relative "app"

module IntentRecord
  module Web
    # Boots the GUI on localhost only. Connects (and migrates) the database first.
    module Boot
      BIND = "127.0.0.1".freeze
      DEFAULT_PORT = 4791

      Options = Struct.new(:port, keyword_init: true)

      module_function

      def parse_argv(argv)
        args = argv.dup
        port = CLI::ArgvParser.take_integer_flag(args, "--port", DEFAULT_PORT)
        Options.new(port: port)
      end

      def run!(config:, argv:)
        opts = parse_argv(argv)
        config.load!
        Database.connect!(config.db_path)
        warn "intent-record GUI on http://#{BIND}:#{opts.port} (db: #{config.db_path})"
        App.run!(bind: BIND, port: opts.port)
      rescue Errno::EADDRINUSE
        raise Error, "Port #{opts.port} is already in use; pass --port to choose another"
      end
    end
  end
end
