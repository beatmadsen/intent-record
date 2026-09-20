require_relative "../application_record"
module IntentRecord
  module Models
    class AssetVersion < ApplicationRecord
      belongs_to :vcs_system
      has_many :intent_record_asset_versions, dependent: :destroy
      # Oldest first, then id, so a commit carrying several intents reads as a
      # story and the order is the query's rather than the plan's or Ruby's.
      has_many :intent_records, -> { order(:created_at, :id) }, through: :intent_record_asset_versions

      validates :external_id, presence: true, uniqueness: { scope: :vcs_system_id }
    end
  end
end
