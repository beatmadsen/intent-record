require_relative "../formatter"
require_relative "../like_pattern"
require_relative "../search_ranking"
require_relative "../models/intent_record"

module IntentRecord
  module Commands
    # Case-insensitive substring search over summary, body, and linked stakeholder uris and titles,
    # so a ticket key such as ACME-42 finds the intents built for it.
    #
    # Substring decides which records answer, relevance decides their order. The
    # two are kept apart deliberately: FTS5 tokenises, so as a filter it would
    # both lose `ACME-4` inside `ACME-42` and let `100%` match `100 percent`,
    # which is the behaviour LikeEscapingTest exists to refuse.
    class Search
      LIMIT = 200
      FIELDS = %w[intent_records.summary intent_records.body stakeholder_sources.uri stakeholder_sources.title].freeze

      def initialize(terms:, match: "any")
        @terms = terms.map(&:strip).reject(&:empty?)
        @match = match
      end

      def call
        raise ValidationError, "At least one search term is required" if @terms.empty?
        raise ValidationError, "--match must be any or all" unless %w[any all].include?(@match)

        { "intents" => matching_records.map { |r| Formatter.full(r) } }
      end

      private

      def matching_records
        Formatter.preloaded(ranked(matching_scope))
      end

      def matching_scope
        Models::IntentRecord.left_joins(:stakeholder_sources)
                            .group("intent_records.id")
                            .having(having_sql, *having_binds)
                            .limit(LIMIT)
      end

      # Terms that hold no searchable token leave nothing to rank, and an empty
      # MATCH is a syntax error rather than an expression matching nothing.
      def ranked(scope)
        expression = SearchRanking.expression_for(@terms)
        return scope.order(Arel.sql(SearchRanking::TIE_BREAK)) if expression.nil?

        order = Models::IntentRecord.sanitize_sql_array([SearchRanking.order_template, expression])
        scope.order(Arel.sql(order))
      end

      def having_sql
        joiner = @match == "all" ? " AND " : " OR "
        @terms.map { "SUM(CASE WHEN #{term_clause} THEN 1 ELSE 0 END) > 0" }.join(joiner)
      end

      def term_clause
        FIELDS.map { |f| LikePattern.contains(f) }.join(" OR ")
      end

      def having_binds
        @terms.flat_map { |t| [LikePattern.contains_bind(t)] * FIELDS.size }
      end
    end
  end
end
