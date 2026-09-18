module IntentRecord
  module Models
    class IntentRecordLink < ApplicationRecord
      belongs_to :source, class_name: "IntentRecord::Models::IntentRecord",
                          foreign_key: :source_intent_record_id, inverse_of: :outgoing_links
      belongs_to :target, class_name: "IntentRecord::Models::IntentRecord",
                          foreign_key: :target_intent_record_id, inverse_of: :incoming_links

      validates :source_intent_record_id, uniqueness: { scope: :target_intent_record_id }
      validate :not_self_referencing

      private

      def not_self_referencing
        return unless source_intent_record_id && source_intent_record_id == target_intent_record_id

        errors.add(:base, "An intent record cannot link to itself")
      end
    end
  end
end
