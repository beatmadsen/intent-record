require_relative "../application_record"
module IntentRecord
  module Models
    class VcsSystem < ApplicationRecord
      has_many :asset_versions, dependent: :restrict_with_exception

      validates :name, presence: true, uniqueness: true
    end
  end
end
