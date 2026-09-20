module IntentRecord
  # Turns the terms a user typed into an FTS5 MATCH expression.
  #
  # FTS5 reads its right-hand side as an expression language, not as text: `100%`
  # is a syntax error and a term such as `OR` or `NEAR` is an operator. Quoting
  # each term makes it a phrase, which is the only form that carries whatever the
  # user typed through the parser unread.
  #
  # Phrases are joined with OR because this expression ranks rather than filters.
  # Which records match is settled before FTS5 is asked, so a term that narrowed
  # the match here would rank a record it was not asked about at zero.
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

    def for(terms)
      phrases = terms.map { |term| phrase(term) }.compact
      return nil if phrases.empty?

      phrases.join(JOINER)
    end

    def phrase(term)
      # A term of pure punctuation tokenises to nothing, and an empty phrase is
      # a syntax error rather than a phrase that matches nothing.
      return nil unless term.to_s.match?(/[[:alnum:]]/)

      "#{QUOTE}#{term.gsub(QUOTE, QUOTE * 2)}#{QUOTE}"
    end

    private_class_method :phrase
  end
end
