require_relative "../formatter"
require_relative "../models/intent_record"

module IntentRecord
  module Commands
    # Case-insensitive substring search over summary and body.
    class Search
      LIMIT = 200

      def initialize(terms:, match: "any")
        @terms = terms.map(&:strip).reject(&:empty?)
        @match = match
      end

      def call
        raise ValidationError, "At least one search term is required" if @terms.empty?
        raise ValidationError, "--match must be any or all" unless %w[any all].include?(@match)

        { "results" => matching_records.map { |r| Formatter.full(r) } }
      end

      private

      def matching_records
        clauses = @terms.map { clause }
        joiner = @match == "all" ? " AND " : " OR "
        Models::IntentRecord.where(clauses.join(joiner), *@terms.flat_map { |t| [like(t)] * 2 })
                            .order(created_at: :desc).limit(LIMIT)
      end

      def clause
        "(LOWER(summary) LIKE ? OR LOWER(body) LIKE ?)"
      end

      def like(term)
        "%#{Models::IntentRecord.sanitize_sql_like(term.downcase)}%"
      end
    end
  end
end
