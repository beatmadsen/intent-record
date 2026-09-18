require_relative "../formatter"
require_relative "../models/stakeholder_source"

module IntentRecord
  module Commands
    # Answers "what did we build for this ticket, and why": every intent linked to a
    # stakeholder source (by exact uri or substring) plus the distinct commits across them.
    class BySource
      def initialize(uri:, contains: false)
        @uri = uri.strip
        @contains = contains
      end

      def call
        sources = matching_sources.includes(:stakeholder_system).to_a
        intents = intents_for(sources)
        { "asset_versions" => distinct_versions(intents), "intents" => intents }.merge(source_keys(sources))
      end

      private

      def source_keys(sources)
        return { "source" => Formatter.source(sources.first) } if sources.size == 1
        return {} if sources.empty?

        { "sources" => sources.map { |s| Formatter.source(s) } }
      end

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

      def distinct_versions(intents)
        intents.flat_map { |i| i["asset_versions"] }.uniq
      end
    end
  end
end
