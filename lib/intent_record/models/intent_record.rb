require_relative "../application_record"
module IntentRecord
  module Models
    class IntentRecord < ApplicationRecord
      SUMMARY_MAX_LENGTH = 350

      # Ordered by the link rows, so a caller reads a record's commits, references
      # and related intents back in the order they attached them. Without an
      # order the answer is whatever the query plan produces, which is not
      # insertion order: SQLite answers from a covering index where it can.
      ATTACHMENT_ORDER = -> { order(:id) }

      has_many :intent_record_asset_versions, ATTACHMENT_ORDER, dependent: :destroy
      has_many :asset_versions, through: :intent_record_asset_versions
      has_many :stakeholder_references, ATTACHMENT_ORDER, dependent: :destroy
      has_many :stakeholder_sources, through: :stakeholder_references
      has_many :outgoing_links, ATTACHMENT_ORDER, class_name: "IntentRecord::Models::IntentRecordLink",
                                                  foreign_key: :source_intent_record_id, dependent: :destroy,
                                                  inverse_of: :source
      has_many :incoming_links, ATTACHMENT_ORDER, class_name: "IntentRecord::Models::IntentRecordLink",
                                                  foreign_key: :target_intent_record_id, dependent: :destroy,
                                                  inverse_of: :target

      validates :global_id, presence: true, length: { is: GlobalId::LENGTH }, uniqueness: true
      validates :summary, presence: true, length: { maximum: SUMMARY_MAX_LENGTH }
      validates :body, presence: true
    end
  end
end
