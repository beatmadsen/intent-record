require_relative "search_index"
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
    TABLE = SearchIndex::TABLE
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
    # once for the search and joined to the candidates. Once, not once per
    # record: a correlated subquery measured eight seconds for a common word on
    # twenty-five thousand records, this a quarter of a second. `LIMIT -1` is
    # what keeps SQLite from flattening the subquery into the outer query, where
    # bm25 and snippet lose their context; the plan reports it as MATERIALIZE,
    # and SearchRankingPlanTest holds it there. The `?` is filled by the caller
    # through sanitize_sql_array.
    JOIN = <<~SQL.squish.freeze
      LEFT JOIN (
        SELECT rowid AS indexed_id,
               bm25(#{TABLE}, #{SUMMARY_WEIGHT}, #{BODY_WEIGHT}) AS relevance,
               #{SearchSnippet::EXPRESSION} AS #{SearchSnippet::COLUMN}
        FROM #{TABLE} WHERE #{TABLE} MATCH ? LIMIT -1
      ) AS #{ALIAS} ON #{ALIAS}.indexed_id = intent_records.id
    SQL

    ORDER = "COALESCE(#{ALIAS}.relevance, #{NO_MATCH_SCORE}) ASC, #{TIE_BREAK}".freeze

    # What a search selects when it ranks: the record, and the fragment the
    # subquery found for it.
    SELECTION = "intent_records.*, #{ALIAS}.#{SearchSnippet::COLUMN} AS #{SearchSnippet::COLUMN}".freeze
  end
end
