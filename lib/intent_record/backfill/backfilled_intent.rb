require_relative "../models/intent_record"

module IntentRecord
  module Backfill
    # The text a backfilled record carries.
    #
    # A commit message says what changed, not why, and backfill cannot invent
    # the why. So the body says plainly that the reasoning was never recorded,
    # and the commit message follows it. The marker is a fixed string, which is
    # what lets an agent find these records later and attach the real reasoning,
    # and what a migration would search for if this ever becomes a column.
    #
    # The message is copied rather than pointed at: the store keeps no
    # repository identity, so "see the commit" names no git anyone could open,
    # and search, by-source and the GUI all read the store alone.
    class BackfilledIntent
      MARKER = "Backfilled from the commit message; the reasoning behind this change was not recorded.".freeze
      SUMMARY_LIMIT = Models::IntentRecord::SUMMARY_MAX_LENGTH
      BLANK_SUMMARY = "Backfilled commit with no message".freeze
      ELLIPSIS = "...".freeze

      def initialize(message:, author:)
        @message = message.to_s
        @author = author
      end

      def to_h
        { "summary" => summary, "body" => body, "author" => @author }
      end

      private

      # A truncated summary loses nothing: the body below keeps the subject
      # whole.
      def summary
        subject.empty? ? BLANK_SUMMARY : truncated(subject)
      end

      def body
        [MARKER, @message.strip].reject(&:empty?).join("\n\n")
      end

      def subject
        @message.strip.lines.first.to_s.strip.gsub(/\s+/, " ")
      end

      def truncated(text)
        return text if text.length <= SUMMARY_LIMIT

        "#{text[0, SUMMARY_LIMIT - ELLIPSIS.length]}#{ELLIPSIS}"
      end
    end
  end
end
