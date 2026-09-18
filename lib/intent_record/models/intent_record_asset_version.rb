module IntentRecord
  module Models
    class IntentRecordAssetVersion < ApplicationRecord
      belongs_to :intent_record
      belongs_to :asset_version

      validates :intent_record_id, uniqueness: { scope: :asset_version_id }
    end
  end
end
