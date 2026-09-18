require "json"

module IntentRecord
  class CLI
    # The JSON object an agent sends on stdin. Nothing here concerns argv, which
    # is why it is not in ArgvParser.
    module StdinJson
      module_function

      def read(stdin)
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
