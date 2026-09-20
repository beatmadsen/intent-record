require_relative "../formatter"
require_relative "../search_membership"
require_relative "../search_ranking"
require_relative "../models/intent_record"

module IntentRecord
  module Commands
    # Search over summary, body, and linked stakeholder uris and titles, so a
    # ticket key such as ACME-42 finds the intents built for it.
    #
    # Which records answer is SearchMembership's decision and what order they
    # answer in is SearchRanking's. The two are kept apart because they read a
    # term differently, and only one of them may be trusted with a term that
    # carries punctuation.
    class Search
      LIMIT = 200
      MATCH_MODES = %w[any all].freeze

      def initialize(terms:, match: "any")
        @terms = terms.map(&:strip).reject(&:empty?)
        @match = match
      end

      def call
        raise ValidationError, "At least one search term is required" if @terms.empty?
        raise ValidationError, "--match must be any or all" unless MATCH_MODES.include?(@match)

        { "intents" => matching_records.map { |r| Formatter.full(r) } }
      end

      private

      def matching_records
        Formatter.preloaded(ranked(matching_scope))
      end

      def matching_scope
        Models::IntentRecord.left_joins(:stakeholder_sources)
                            .group("intent_records.id")
                            .having(*SearchMembership.new(terms: @terms, match: @match).condition)
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
    end
  end
end
