require_relative "../formatter"
require_relative "../models/stakeholder_source"

module IntentRecord
  module Commands
    # Intents (and thereby commits) linked to a stakeholder source, by exact uri or substring.
    class BySource
      def initialize(uri:, contains: false)
        @uri = uri.strip
        @contains = contains
      end

      def call
        sources = matching_sources.includes(:stakeholder_system).to_a
        result = { "intents" => intents_for(sources) }
        result["source"] = Formatter.source(sources.first) if sources.size == 1
        result["sources"] = sources.map { |s| Formatter.source(s) } if sources.size > 1
        result
      end

      private

      def matching_sources
        return Models::StakeholderSource.where(uri: @uri) unless @contains

        pattern = "%#{Models::StakeholderSource.sanitize_sql_like(@uri.downcase)}%"
        Models::StakeholderSource.where("LOWER(uri) LIKE ?", pattern)
      end

      def intents_for(sources)
        Models::IntentRecord.joins(:stakeholder_references)
                            .where(stakeholder_references: { stakeholder_source_id: sources.map(&:id) })
                            .distinct.order(:created_at).map { |r| Formatter.full(r) }
      end
    end
  end
end
