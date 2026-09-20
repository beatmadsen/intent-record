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

    module_function

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
