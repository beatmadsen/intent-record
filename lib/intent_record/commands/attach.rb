require_relative "../formatter"
require_relative "../models/intent_record"
require_relative "../linkers/asset_version_linker"
require_relative "../linkers/stakeholder_linker"
require_relative "../linkers/intent_linker"

module IntentRecord
  module Commands
    # Links more commits, stakeholder sources or related intents to an existing intent record.
    class Attach
      LINK_KEYS = %w[commits asset_versions stakeholder_references related_intent_ids].freeze

      def initialize(intent_id:)
        @intent_id = intent_id
      end

      def call(input)
        record = Models::IntentRecord.find_by(global_id: @intent_id)
        raise NotFoundError, "Intent record not found: #{@intent_id}" unless record
        raise ValidationError, "Nothing to attach: provide one of #{LINK_KEYS.join(", ")}" if nothing_to_attach?(input)

        ActiveRecord::Base.transaction { link_all(record, input) }
        Formatter.full(record.reload)
      end

      private

      def nothing_to_attach?(input)
        LINK_KEYS.none? { |key| input[key].is_a?(Array) && input[key].any? }
      end

      def link_all(record, input)
        Linkers::AssetVersionLinker.call(record, input)
        Linkers::StakeholderLinker.call(record, input)
        Linkers::IntentLinker.call(record, input)
      end
    end
  end
end
