require_relative "../asset_version_resolver"
require_relative "../formatter"

module IntentRecord
  module Commands
    # Everything recorded against one commit (or other asset version).
    class Lookup
      def initialize(external_id:, vcs: nil)
        @external_id = external_id
        @vcs = vcs
      end

      def call
        version = AssetVersionResolver.new(external_id: @external_id, vcs: @vcs).call
        {
          "asset_version" => Formatter.asset_version(version),
          "intents" => version.intent_records.order(:created_at).map { |r| Formatter.full(r) }
        }
      end
    end
  end
end
