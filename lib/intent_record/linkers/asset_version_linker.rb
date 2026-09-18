require_relative "../models/vcs_system"
require_relative "../models/asset_version"
require_relative "../models/intent_record_asset_version"
require_relative "../input_validator"

module IntentRecord
  module Linkers
    # Links an intent record to asset versions. Accepts `commits` (git shorthand) and
    # `asset_versions` ([{vcs, external_id}]). Returns the linked versions.
    class AssetVersionLinker
      DEFAULT_VCS = "git".freeze

      def self.call(record, input)
        new(record).call(input)
      end

      def initialize(record)
        @record = record
      end

      def call(input)
        specs(input).map { |vcs, external_id| link!(vcs, external_id) }
      end

      private

      def specs(input)
        commits = InputValidator.non_blank_strings!(InputValidator.array!(input, "commits"), "commit")
        explicit = InputValidator.hashes_with!(InputValidator.array!(input, "asset_versions"),
                                               "asset_versions", "vcs", "external_id")
        commits.map { |c| [DEFAULT_VCS, c] } + explicit.map { |v| [v["vcs"], v["external_id"]] }
      end

      def link!(vcs, external_id)
        version = find_or_create_version(vcs.strip.downcase, external_id.strip)
        Models::IntentRecordAssetVersion.find_or_create_by!(intent_record: @record, asset_version: version) do |l|
          l.created_at = Time.now.utc
        end
        version
      end

      def find_or_create_version(vcs, external_id)
        system = Models::VcsSystem.find_or_create_by!(name: vcs) { |s| s.created_at = Time.now.utc }
        Models::AssetVersion.find_or_create_by!(vcs_system: system, external_id: external_id) do |v|
          v.created_at = Time.now.utc
        end
      end
    end
  end
end
