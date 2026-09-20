require_relative "match_expression"

module IntentRecord
  # The order a search answers in.
  #
  # Which records match is settled by the substring search, because that is what
  # a person typing `100%` or `ACME-4` is asking for and FTS5 cannot answer it:
  # it tokenises, so it neither sees a substring inside a word nor tells `100%`
  # from `100 percent`. What it can do is say which of the matches the terms are
  # actually about, and that is all it is asked here.
  #
  # bm25 returns a negative score, better the lower, so ascending is best first.
  # A record the index cannot see scores nothing and sorts after every record it
  # can, which is the right place for a hit the terms only touch as a substring.
  module SearchRanking
    TABLE = "intent_search".freeze

    # Weights per indexed column, in the order the index declares them. A term in
    # a one-line summary is a stronger signal than the same term somewhere in a
    # body that may run for pages, and bm25's own length normalisation does not
    # say so on its own.
    SUMMARY_WEIGHT = 10.0
    BODY_WEIGHT = 1.0

    # Every ranked list needs a total order, or the rows that tie come back in
    # whatever order the plan produces. Newest first among equals, then id, which
    # is the order `recent` already answers in.
    TIE_BREAK = "intent_records.created_at DESC, intent_records.id DESC".freeze

    NO_MATCH_SCORE = 0.0

    # The terms are left as a placeholder rather than pasted in, so building this
    # needs no connection and the one value that came from the user is bound.
    RELEVANCE = <<~SQL.squish.freeze
      (SELECT bm25(#{TABLE}, #{SUMMARY_WEIGHT}, #{BODY_WEIGHT}) FROM #{TABLE}
       WHERE #{TABLE} MATCH ? AND #{TABLE}.rowid = intent_records.id)
    SQL

    module_function

    # A correlated subquery rather than a join, because bm25 only works where
    # SQLite has kept the query's FTS context. Measured on SQLite 3.53.2: a
    # LEFT JOIN onto the index, a join onto a subquery over it, and a plain CTE
    # all fail with "unable to use function bm25 in the requested context" once
    # the outer query groups, because SQLite flattens them. A CTE marked
    # MATERIALIZED survives, but ActiveRecord renders no such hint.
    def order_template
      "COALESCE(#{RELEVANCE}, #{NO_MATCH_SCORE}) ASC, #{TIE_BREAK}"
    end

    def expression_for(terms)
      MatchExpression.for(terms)
    end
  end
end
