module IntentRecord
  module Backfill
    # What one dry run saw: the sources it would create and the commit subjects
    # that matched nothing. A write run collects neither, because it is not an
    # inspection, and reports neither.
    class Inspection
      # A real history has thousands of unmatched commits and nobody reads
      # thousands of lines. Enough to recognise a convention, not enough to bury
      # the counts.
      UNMATCHED_SHOWN = 20

      def initialize(collecting)
        @collecting = collecting
        @sources = []
        @unmatched = []
      end

      def missed(subject)
        @unmatched << subject if listable?(subject)
        :skipped
      end

      def noted(references)
        @sources.concat(references.map { |r| r["uri"] }) if @collecting
      end

      def to_h
        return {} unless @collecting

        { "dry_run" => true, "sources" => @sources.uniq, "unmatched" => @unmatched }
      end

      private

      # A commit with no message has no subject to show, and a column of blank
      # lines says nothing about what the pattern missed.
      def listable?(subject)
        @collecting && room_left? && !subject.empty?
      end

      def room_left?
        @unmatched.size < UNMATCHED_SHOWN
      end
    end
  end
end
