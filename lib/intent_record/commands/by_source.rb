require_relative "../formatter"
require_relative "../like_pattern"
require_relative "../stakeholder_normalizer"
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
        {
          "sources" => sources.map { |s| Formatter.source(s) },
          "asset_versions" => intents.flat_map { |i| i["asset_versions"] }.uniq,
          "intents" => intents
        }
      end

      private

      def matching_sources
        return Models::StakeholderSource.where(uri: StakeholderNormalizer.uri(@uri)) unless @contains

        Models::StakeholderSource.where(LikePattern.contains("uri"), LikePattern.contains_bind(@uri))
      end

      def intents_for(sources)
        Models::IntentRecord.joins(:stakeholder_references)
                            .where(stakeholder_references: { stakeholder_source_id: sources.map(&:id) })
                            .distinct.order(:created_at).map { |r| Formatter.full(r) }
      end
    end
  end
end
