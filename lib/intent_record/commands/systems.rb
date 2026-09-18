require_relative "../models/vcs_system"
require_relative "../models/stakeholder_system"

module IntentRecord
  module Commands
    # Vocabulary discovery: which vcs and stakeholder system names are known.
    class Systems
      def call
        {
          "vcs_systems" => Models::VcsSystem.order(:name).pluck(:name),
          "stakeholder_systems" => Models::StakeholderSystem.order(:name).pluck(:name)
        }
      end
    end
  end
end
