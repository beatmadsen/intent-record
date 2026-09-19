module IntentRecord
  module Backfill
    # Reads the stakeholder references a commit message names, as the
    # `stakeholder_references` entries `record` already accepts. Nothing here
    # reaches the database.
    class ReferenceScanner
      # A pattern that backtracks catastrophically would otherwise hang the
      # command with no output, on input the person cannot see. The budget is
      # per message and generous: a pattern anyone would write finishes in
      # microseconds.
      MATCH_TIMEOUT_SECONDS = 2.0

      def initialize(system:, pattern:, uri_prefix:)
        @system = system
        @pattern = compiled(pattern)
        @uri_prefix = uri_prefix.to_s
      end

      def call(message)
        found = matching { matches(message) }
        distinct(found).map { |m| reference(m) }
      end

      # Ruby's engine memoises its way out of the catastrophic patterns anyone
      # can construct, so this rarely fires. It is still the difference between
      # a command that reports and one that hangs with no output, on a Ruby
      # whose engine gives up, and it is public because that is the only way to
      # prove the translation happens.
      def matching
        yield
      rescue Regexp::TimeoutError
        raise ValidationError,
              "--pattern took longer than #{MATCH_TIMEOUT_SECONDS}s on one commit message; " \
              "it probably backtracks catastrophically"
      end

      private

      # A message naming the same ticket twice, as merge commits do, asks for
      # one source and not two. Keyed on the uri, because that is what makes a
      # source the same source downstream.
      def distinct(found)
        found.uniq { |m| m[:uri] }
      end

      def compiled(pattern)
        Regexp.new(pattern, timeout: MATCH_TIMEOUT_SECONDS)
      rescue RegexpError => e
        raise ValidationError, "--pattern is not a valid regular expression: #{e.message}"
      end

      # Scanned as MatchData rather than with String#scan, because scan throws
      # away the matched text as soon as the pattern has a group, and the title
      # needs it.
      def matches(message)
        message.to_s.to_enum(:scan, @pattern).map { Regexp.last_match }
               .map { |m| { uri: uri_for(key_of(m)), title: m[0] } }
      end

      def reference(match)
        { "system" => @system, "uri" => match[:uri], "title" => match[:title] }
      end

      def uri_for(key)
        "#{@uri_prefix}#{key}"
      end

      # A pattern with a group says the uri is narrower than the text that found
      # it: `ENG-(\d+)` finds `ENG-7` and means `7`, so the prefix can carry the
      # project. With no group the whole match is the key.
      def key_of(match)
        match.size > 1 ? match[1] : match[0]
      end
    end
  end
end
