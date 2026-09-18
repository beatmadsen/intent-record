require_relative "../models/vcs_system"
require_relative "../models/asset_version"
require_relative "../models/intent_record_asset_version"
require_relative "../asset_version_normalizer"
require_relative "asset_version_specs"

module IntentRecord
  module Linkers
    # Links an intent record to the asset versions a payload names. Reading the
    # payload is AssetVersionSpecs; this writes the rows. Returns the versions.
    class AssetVersionLinker
      def self.call(record, input)
        new(record).call(input)
      end

      def initialize(record)
        @record = record
      end

      def call(input)
        AssetVersionSpecs.from(input).map { |vcs, external_id| link!(vcs, external_id) }
      end

      private

      def link!(raw_vcs, raw_id)
        vcs = AssetVersionNormalizer.vcs_name(raw_vcs)
        version = find_or_create_version(vcs, AssetVersionNormalizer.external_id(vcs, raw_id))
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
