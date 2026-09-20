require_relative "like_pattern"
require_relative "match_expression"

module IntentRecord
  # Which records a search answers with.
  #
  # Two ways of matching sit behind one condition. Substring matching reads a
  # term as the literal it is, which is what a person typing `100%` or `ACME-4`
  # is asking for. The index reads it as a word, which is what finds `retried`
  # for someone who typed `retry`.
  #
  # They are not interchangeable, and the index is the narrower of the two in
  # one direction and the wider in the other. It cannot see inside a word, so it
  # would lose `ACME-4` in `ACME-42`; and it drops punctuation, so, measured, it
  # matches `100 percent` for `100%` and `done now` for `done_now`. A term
  # carrying punctuation therefore gets the substring arm alone.
  class SearchMembership
    # Where a substring is looked for. The index covers only the record's own
    # text, so a stakeholder uri or title is matched as a substring either way.
    FIELDS = %w[intent_records.summary intent_records.body
                stakeholder_sources.uri stakeholder_sources.title].freeze

    INDEX_ARM = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM #{SearchRanking::TABLE}
              WHERE #{SearchRanking::TABLE} MATCH ?
              AND #{SearchRanking::TABLE}.rowid = intent_records.id)
    SQL

    JOINERS = { "all" => " AND ", "any" => " OR " }.freeze

    def initialize(terms:, match:)
      @terms = terms
      @match = match
    end

    # Ready for `having`: the condition followed by its binds, in order.
    def condition
      clauses = @terms.map { |term| clause(term) }
      [clauses.map(&:first).join(JOINERS.fetch(@match)), *clauses.flat_map { |c| c.drop(1) }]
    end

    private

    def clause(term)
      arms = [substring_arm, *index_arm(term)]
      ["(#{arms.join(" OR ")})", *substring_binds(term), *index_binds(term)]
    end

    # Counted rather than tested for, because the join to stakeholder_sources
    # gives a record one row per source and the condition is read after grouping.
    def substring_arm
      "SUM(CASE WHEN #{FIELDS.map { |f| LikePattern.contains(f) }.join(" OR ")} THEN 1 ELSE 0 END) > 0"
    end

    def substring_binds(term)
      [LikePattern.contains_bind(term)] * FIELDS.size
    end

    def index_arm(term)
      MatchExpression.word?(term) ? [INDEX_ARM] : []
    end

    def index_binds(term)
      MatchExpression.word?(term) ? [MatchExpression.for([term])] : []
    end
  end
end
