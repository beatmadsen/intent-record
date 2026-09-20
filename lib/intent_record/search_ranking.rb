require_relative "match_expression"
require_relative "search_snippet"

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
    ALIAS = "ranking".freeze

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

    # The relevance and the fragment for every record the terms match, computed
    # once for the search and joined to the candidates.
    #
    # Once, not once per record, is the whole point of the shape. bm25 and
    # snippet only evaluate where SQLite has kept the query's FTS context, and
    # under the GROUP BY the membership needs, a plain join onto this subquery is
    # flattened into the outer query and loses it. A correlated subquery keeps
    # it but is planned as a scan of the whole match set for every candidate
    # row: measured, eight seconds for a common word on twenty-five thousand
    # records, against a quarter of a second for this.
    #
    # `LIMIT -1` is SQLite's "no limit" and is here only because a subquery with
    # a LIMIT is one the flattener leaves alone, which the query plan reports as
    # MATERIALIZE. It is the documented behaviour of the flattener rather than
    # a hint, since ActiveRecord renders no MATERIALIZED for a CTE.
    #
    # The terms are left as a placeholder rather than pasted in, so building
    # this needs no connection. The caller fills it through sanitize_sql_array,
    # which quotes the one value that came from the user before it reaches the
    # query text.
    JOIN = <<~SQL.squish.freeze
      LEFT JOIN (
        SELECT rowid AS indexed_id,
               bm25(#{TABLE}, #{SUMMARY_WEIGHT}, #{BODY_WEIGHT}) AS relevance,
               #{SearchSnippet::EXPRESSION} AS #{SearchSnippet::COLUMN}
        FROM #{TABLE} WHERE #{TABLE} MATCH ? LIMIT -1
      ) AS #{ALIAS} ON #{ALIAS}.indexed_id = intent_records.id
    SQL

    ORDER = "COALESCE(#{ALIAS}.relevance, #{NO_MATCH_SCORE}) ASC, #{TIE_BREAK}".freeze

    module_function

    def join_template
      JOIN
    end

    def order_sql
      ORDER
    end

    def expression_for(terms)
      MatchExpression.for(terms)
    end
  end
end
