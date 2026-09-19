require_relative "../models/intent_record"
require_relative "../models/stakeholder_source"
require_relative "../stakeholder_normalizer"

module IntentRecord
  module Backfill
    # The intent a new record for these references builds on: the most recent
    # earlier record against the same stakeholder source.
    #
    # The most recent one only, because linking to every earlier commit for a
    # ticket would say each builds on all of them, which the history does not
    # support. Asked of the store rather than remembered within a run, so a
    # second run continues the chain the first one left.
    module PredecessorFinder
      module_function

      # A commit naming two tickets with the same predecessor asks for that
      # link once, which IntentLinker's find-or-create already settles, so the
      # duplicate is left for it rather than removed twice.
      def for(references)
        references.filter_map { |reference| latest_intent_for(reference) }
      end

      def latest_intent_for(reference)
        newest(intents_against(source_id(reference)))
      end

      def intents_against(source_id)
        Models::IntentRecord.joins(:stakeholder_sources).where(stakeholder_sources: { id: source_id })
      end

      def newest(intents)
        intents.order(created_at: :desc, id: :desc).first&.global_id
      end

      def source_id(reference)
        Models::StakeholderSource.joins(:stakeholder_system)
                                 .find_by(stakeholder_systems: { name: system_name(reference) },
                                          uri: StakeholderNormalizer.uri(reference["uri"]))&.id
      end

      def system_name(reference)
        StakeholderNormalizer.system_name(reference["system"])
      end

      private_class_method :latest_intent_for, :intents_against, :newest, :source_id, :system_name
    end
  end
end
