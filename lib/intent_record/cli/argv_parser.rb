require "json"

module IntentRecord
  class CLI
    # Argv-mutating helpers; each `take_*` removes matched tokens from argv.
    module ArgvParser
      module_function

      def take_flag(argv, name)
        idx = argv.index(name)
        return nil unless idx && argv[idx + 1]

        value = argv[idx + 1]
        argv.delete_at(idx + 1)
        argv.delete_at(idx)
        value
      end

      def take_integer_flag(argv, name, default)
        raw = take_flag(argv, name)
        return default if raw.nil?
        raise ValidationError, "#{name} requires an integer, got #{raw.inspect}" unless /\A\d+\z/.match?(raw)

        raw.to_i
      end

      def take_required_positional(argv, label)
        value = argv.shift
        raise ValidationError, "#{label} is required" if value.nil? || value.strip.empty?

        value
      end

      def read_stdin_json(stdin)
        raw = stdin.read
        raise ValidationError, "Empty input" if raw.nil? || raw.strip.empty?

        parsed = JSON.parse(raw)
        raise ValidationError, "Input must be a JSON object" unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError => e
        raise ValidationError, "Invalid JSON input: #{e.message}"
      end
    end
  end
end
