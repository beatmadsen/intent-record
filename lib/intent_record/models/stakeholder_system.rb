require_relative "../application_record"
module IntentRecord
  module Models
    class StakeholderSystem < ApplicationRecord
      has_many :stakeholder_sources, dependent: :restrict_with_exception

      validates :name, presence: true, uniqueness: true
    end
  end
end
