require_relative "../blame/porcelain"
require_relative "stdin_json"

module IntentRecord
  class CLI
    # What `blame` reads from stdin. The JSON shape is the contract; a format
    # names a reader that produces it from what some blame tool already prints.
    module BlameInput
      FORMATS = { "git-porcelain" => Blame::Porcelain }.freeze

      module_function

      def read(format, stdin)
        return StdinJson.read(stdin) if format.nil?

        reader = FORMATS[format]
        raise ValidationError, "Unknown --format #{format}. Known formats: #{FORMATS.keys.join(", ")}" if reader.nil?

        { "lines" => reader.lines(stdin.read) }
      end
    end
  end
end
