module IntentRecord
  module Models
    class AssetVersion < ApplicationRecord
      belongs_to :vcs_system
      has_many :intent_record_asset_versions, dependent: :destroy
      has_many :intent_records, through: :intent_record_asset_versions

      validates :external_id, presence: true, uniqueness: { scope: :vcs_system_id }
    end
  end
end
