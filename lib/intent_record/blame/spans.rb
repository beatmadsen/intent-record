require_relative "../input_validator"

module IntentRecord
  module Blame
    # Reads a blame payload into the spans a reader is answered with.
    #
    # A blame tool answers per line, and a reader asked about a range. Answering
    # per line would bury the useful part in repetition, so neighbouring lines
    # from one change become one span. Neighbouring, not merely equal: the same
    # change either side of someone else's edit is two places in the file, and
    # one span across them would claim a line it does not own.
    #
    # Nothing here reaches the database, so a malformed payload is refused before
    # the store is asked anything.
    class Spans
      Span = Struct.new(:external_id, :from, :to)

      def initialize(lines)
        @lines = lines
      end

      def call
        collapse(sorted)
      end

      private

      def sorted
        raise ValidationError, "At least one line is required" unless @lines.is_a?(Array) && @lines.any?

        entries = @lines.map { |line| entry(line) }.sort_by(&:first)
        reject_repeats(entries)
        entries
      end

      # Sorted, so a repeat is adjacent. The same line attributed to two changes
      # is a contradiction in the payload, and answering it would mean choosing
      # one of them silently.
      def reject_repeats(entries)
        entries.each_cons(2) do |(earlier, _), (later, _)|
          raise ValidationError, "Line #{earlier} is given more than once" if earlier == later
        end
      end

      def entry(line)
        raise ValidationError, "Each line needs a line and an external_id" unless line.is_a?(Hash)

        [line_number(line["line"]), InputValidator.required_string!(line, "external_id")]
      end

      # A string is read in base ten: Integer() on its own reads "010" as
      # octal and answers about line 8, a wrong answer given confidently. A
      # fraction is refused rather than truncated for the same reason.
      def line_number(raw)
        number = raw.is_a?(Integer) ? raw : Integer(raw.to_s, 10, exception: false)
        raise ValidationError, "line must be a positive integer, got #{raw.inspect}" if number.nil? || number < 1

        number
      end

      # Walks in file order, extending the span in hand while the next line both
      # follows the last one and names the same change.
      def collapse(entries)
        entries.each_with_object([]) do |(number, id), spans|
          extends?(spans.last, number, id) ? spans.last.to = number : spans << Span.new(id, number, number)
        end
      end

      def extends?(span, number, id)
        !span.nil? && span.external_id == id && span.to == number - 1
      end
    end
  end
end
