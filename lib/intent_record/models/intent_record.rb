module IntentRecord
  module Models
    class IntentRecord < ApplicationRecord
      SUMMARY_MAX_LENGTH = 350

      has_many :intent_record_asset_versions, dependent: :destroy
      has_many :asset_versions, through: :intent_record_asset_versions
      has_many :stakeholder_references, dependent: :destroy
      has_many :stakeholder_sources, through: :stakeholder_references
      has_many :outgoing_links, class_name: "IntentRecord::Models::IntentRecordLink",
                                foreign_key: :source_intent_record_id, dependent: :destroy,
                                inverse_of: :source
      has_many :incoming_links, class_name: "IntentRecord::Models::IntentRecordLink",
                                foreign_key: :target_intent_record_id, dependent: :destroy,
                                inverse_of: :target

      validates :global_id, presence: true, length: { is: GlobalId::LENGTH }, uniqueness: true
      validates :summary, presence: true, length: { maximum: SUMMARY_MAX_LENGTH }
      validates :body, presence: true
    end
  end
end
