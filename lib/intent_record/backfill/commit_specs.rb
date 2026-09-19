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
          message: message(entry),
          author: InputValidator.optional_string!(entry, "author"),
          ref: InputValidator.optional_string!(entry, "ref") }
      end

      # An empty commit message is rare and real, and it names no ticket, so it
      # is the same as any commit matching nothing. Refusing it would abort a
      # whole history over one commit nobody wrote a message for. A message that
      # is not a string is still a malformed payload rather than an absent one.
      def message(entry)
        InputValidator.optional_string!(entry, "message").to_s
      end

      private_class_method :entries, :spec, :message
    end
  end
end
