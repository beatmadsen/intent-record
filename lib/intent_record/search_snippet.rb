require_relative "search_index"

module IntentRecord
  # What a search result shows instead of the whole body.
  #
  # A result carries the whole body, which is right for an agent reading one
  # record and wrong for a person scanning two hundred. The index can say which
  # part of a body the terms landed in, and that is the part worth reading first.
  #
  # It can only say it for a record it matched, though, and a term matched as a
  # substring inside a longer word is one it never saw. Those fall back to the
  # opening of the body, so every result carries something rather than leaving a
  # blank in a list where every other row has text.
  module SearchSnippet
    # Roughly a sentence or two either side of the match, which is enough to see
    # why a record answered without turning the list back into a wall of prose.
    INDEX_TOKENS = 20
    FALLBACK_LENGTH = 200
    ELLIPSIS = "…".freeze

    # Marks are left empty deliberately. A fragment with `[` and `]` around the
    # match reads as punctuation the writer typed, and a fragment with HTML in it
    # is either escaped into visible markup or trusted, and neither is wanted.
    # Column 1 is the body. Evaluated inside SearchRanking's subquery, which is
    # the one place a search still holds the index's context.
    EXPRESSION = "snippet(#{SearchIndex::TABLE}, 1, '', '', '#{ELLIPSIS}', #{INDEX_TOKENS})".freeze

    COLUMN = "snippet".freeze

    module_function

    def text(indexed:, body:)
      return indexed unless indexed.nil? || indexed.empty?

      shortened(body.to_s)
    end

    # Cut at the last space where there is one, so the reader is not shown a
    # fragment of a word. Japanese and Chinese prose has no spaces, and neither
    # does a long url or a hash, and a cut that found no space and kept nothing
    # showed an ellipsis on its own.
    def shortened(body)
      return body if body.length <= FALLBACK_LENGTH

      cut = body[0, FALLBACK_LENGTH]
      at_word = cut.rpartition(/\s/).first.rstrip
      "#{at_word.empty? ? cut : at_word}#{ELLIPSIS}"
    end

    private_class_method :shortened
  end
end
