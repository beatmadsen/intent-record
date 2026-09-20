require_relative "../formatter"
require_relative "../match_expression"
require_relative "../search_membership"
require_relative "../search_ranking"
require_relative "../search_snippet"
require_relative "../search_term"
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
        @raw = terms.map(&:strip).reject(&:empty?)
        @match = match
      end

      def call
        raise ValidationError, "At least one search term is required" if @raw.empty?
        raise ValidationError, "--match must be any or all" unless MATCH_MODES.include?(@match)

        @terms = @raw.map { |term| SearchTerm.parse(term) }
        { "intents" => matching_records.map { |r| formatted(r) } }
      end

      private

      # The snippet belongs to the search rather than to the record, so it is
      # merged here instead of in Formatter, which every other command shares.
      def formatted(record)
        snippet = SearchSnippet.text(indexed: record[SearchSnippet::COLUMN], body: record.body)
        Formatter.full(record).merge(SearchSnippet::COLUMN => snippet)
      end

      def matching_records
        Formatter.preloaded(with_ranking(matching_scope))
      end

      def matching_scope
        Models::IntentRecord.left_joins(:stakeholder_sources)
                            .group("intent_records.id")
                            .having(*SearchMembership.new(terms: @terms, match: @match).condition)
                            .limit(LIMIT)
      end

      # Only the terms the index may answer rank anything. A term it may not be
      # trusted with would rank by text the person did not ask for, which is the
      # same reason it does not decide membership either.
      def indexable
        @terms.select(&:indexable?)
      end

      # Joins the relevance and fragment the index found, and orders by them.
      # Terms that hold no searchable token leave nothing to rank, and an empty
      # MATCH is a syntax error rather than an expression matching nothing, so
      # that case orders by the tie-break alone and the body stands in for the
      # fragment.
      def with_ranking(scope)
        expression = MatchExpression.for(indexable)
        return scope.order(Arel.sql(SearchRanking::TIE_BREAK)) if expression.nil?

        join = Models::IntentRecord.sanitize_sql_array([SearchRanking::JOIN, expression])
        scope.select(SearchRanking::SELECTION).joins(join).order(Arel.sql(SearchRanking::ORDER))
      end
    end
  end
end
