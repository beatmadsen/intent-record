require_relative "../application_record"
module IntentRecord
  module Models
    class StakeholderReference < ApplicationRecord
      belongs_to :intent_record
      belongs_to :stakeholder_source

      validates :intent_record_id, uniqueness: { scope: :stakeholder_source_id }
    end
  end
end
