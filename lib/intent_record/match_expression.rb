module IntentRecord
  # Turns the terms a user typed into an FTS5 MATCH expression.
  #
  # FTS5 reads its right-hand side as an expression language, not as text: `100%`
  # is a syntax error and a term such as `OR` or `NEAR` is an operator. Quoting
  # each term makes it a phrase, which is the only form that carries whatever the
  # user typed through the parser unread.
  #
  # Phrases are joined with OR. The expression is used twice, and OR is right
  # for both: SearchMembership asks the index one term at a time, so an
  # expression there holds a single phrase and the joiner never applies; and
  # SearchRanking asks it about every term at once, where a record is scored on
  # whichever terms it holds rather than dropped for lacking one, because which
  # records answer has already been settled and AND would score some of them at
  # nothing.
  module MatchExpression
    JOINER = " OR ".freeze
    QUOTE = '"'.freeze

    # A term the index may be trusted with: letters, digits and the spaces
    # between them, and at least one letter or digit to tokenise. Anything else
    # the index would drop, and dropping punctuation is how `100%` comes to
    # match a record that only ever said `100 percent`.
    WORD = /\A(?=.*[[:alnum:]])[[:alnum:][:space:]]+\z/

    module_function

    def word?(term)
      WORD.match?(term.to_s)
    end

    # Takes SearchTerms, which carry the text and the column the person named.
    def for(terms)
      phrases = terms.map { |term| phrase(term) }.compact
      return nil if phrases.empty?

      phrases.join(JOINER)
    end

    def phrase(term)
      # A term of pure punctuation tokenises to nothing, and an empty phrase is
      # a syntax error rather than a phrase that matches nothing.
      return nil unless term.text.match?(/[[:alnum:]]/)

      column(term.index_column) + quoted(term.text)
    end

    # FTS5 reads `summary:"retry"` as that phrase in that column only. A term
    # naming no column is left unprefixed and is answered over all of them.
    def column(name)
      name.nil? ? "" : "#{name}:"
    end

    def quoted(text)
      "#{QUOTE}#{text.gsub(QUOTE, QUOTE * 2)}#{QUOTE}"
    end

    private_class_method :phrase, :column, :quoted
  end
end
