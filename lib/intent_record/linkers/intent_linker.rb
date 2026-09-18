require_relative "../models/intent_record"
require_relative "../models/intent_record_link"
require_relative "../input_validator"

module IntentRecord
  module Linkers
    # Links an intent record to earlier intent records it builds on (`related_intent_ids`).
    class IntentLinker
      def self.call(record, input)
        new(record).call(input)
      end

      def initialize(record)
        @record = record
      end

      def call(input)
        ids = InputValidator.non_blank_strings!(InputValidator.array!(input, "related_intent_ids"), "related_intent_id")
        ids.map { |id| link!(id) }
      end

      private

      def link!(global_id)
        raise ValidationError, "An intent record cannot link to itself" if global_id == @record.global_id

        target = Models::IntentRecord.find_by(global_id: global_id)
        raise NotFoundError, "Related intent record not found: #{global_id}" unless target

        Models::IntentRecordLink.find_or_create_by!(source: @record, target: target) { |l| l.created_at = Time.now.utc }
        target
      end
    end
  end
end
