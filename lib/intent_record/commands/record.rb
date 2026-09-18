require_relative "../input_validator"
require_relative "../formatter"
require_relative "../global_id"
require_relative "../models/intent_record"
require_relative "../linkers/asset_version_linker"
require_relative "../linkers/stakeholder_linker"
require_relative "../linkers/intent_linker"

module IntentRecord
  module Commands
    # Creates an intent record and links it to commits, stakeholder sources and related intents.
    class Record
      def call(input)
        attributes = validated(input)

        ActiveRecord::Base.transaction do
          record = Models::IntentRecord.create!(attributes)
          link_all(record, input)
          Formatter.full(record)
        end
      end

      private

      def validated(input)
        { global_id: GlobalId.unique_for(Models::IntentRecord),
          summary: summary(input),
          body: InputValidator.required_string!(input, "body"),
          author: InputValidator.optional_string!(input, "author"),
          created_at: Time.now.utc }
      end

      def summary(input)
        InputValidator.required_string!(input, "summary", max_length: Models::IntentRecord::SUMMARY_MAX_LENGTH)
                      .gsub(/\s+/, " ")
      end

      def link_all(record, input)
        Linkers::AssetVersionLinker.call(record, input)
        Linkers::StakeholderLinker.call(record, input)
        Linkers::IntentLinker.call(record, input)
      end
    end
  end
end
