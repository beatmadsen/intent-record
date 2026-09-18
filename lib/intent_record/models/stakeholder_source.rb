module IntentRecord
  module Models
    class StakeholderSource < ApplicationRecord
      belongs_to :stakeholder_system
      has_many :stakeholder_references, dependent: :destroy
      has_many :intent_records, through: :stakeholder_references

      validates :uri, presence: true, uniqueness: { scope: :stakeholder_system_id }
    end
  end
end
