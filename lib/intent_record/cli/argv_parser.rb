require "json"

module IntentRecord
  class CLI
    # Argv-mutating helpers; each `take_*` removes matched tokens from argv.
    # Options may be given as `--name value` or `--name=value`.
    module ArgvParser
      module_function

      def take_flag(argv, name)
        indexes = argv.each_index.select { |i| argv[i] == name || argv[i].start_with?("#{name}=") }
        raise ValidationError, "#{name} given more than once" if indexes.size > 1
        return nil if indexes.empty?

        extract_flag(argv, indexes.first, name)
      end

      def extract_flag(argv, idx, name)
        token = argv[idx]
        return argv.delete_at(idx).delete_prefix("#{name}=") if token.include?("=")
        return nil unless argv[idx + 1] && !argv[idx + 1].start_with?("--")

        value = argv[idx + 1]
        argv.slice!(idx, 2)
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

      def take_switch?(argv, name)
        !argv.delete(name).nil?
      end

      def reject_leftovers!(argv)
        return if argv.empty?

        raise ValidationError, "Unexpected argument(s): #{argv.join(" ")}"
      end

      def read_stdin_json(stdin)
        raw = stdin.read.to_s.dup.force_encoding(Encoding::UTF_8)
        raise ValidationError, "Input is not valid UTF-8" unless raw.valid_encoding?
        raise ValidationError, "Empty input" if raw.strip.empty?

        parse_object(raw)
      end

      def parse_object(raw)
        parsed = JSON.parse(raw)
        raise ValidationError, "Input must be a JSON object" unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError => e
        raise ValidationError, "Invalid JSON input: #{e.message}"
      end
    end
  end
end
