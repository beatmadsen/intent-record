require_relative "../input_validator"

module IntentRecord
  module Backfill
    # Reads what a backfill payload says about each commit. Every entry is
    # checked before any is returned, so a payload with a bad entry late in the
    # list never reaches the database. Nothing here needs one.
    module CommitSpecs
      module_function

      def from(input)
        entries(input).map { |entry| spec(entry) }
      end

      def entries(input)
        InputValidator.array!(input, "commits")
      end

      def spec(entry)
        raise ValidationError, "commits entries must be objects" unless entry.is_a?(Hash)

        { commit: InputValidator.required_string!(entry, "commit"),
          message: InputValidator.required_string!(entry, "message"),
          author: InputValidator.optional_string!(entry, "author"),
          ref: InputValidator.optional_string!(entry, "ref") }
      end

      private_class_method :entries, :spec
    end
  end
end
