require_relative "models/asset_version"
require_relative "models/vcs_system"

module IntentRecord
  # Resolves an external id (full or unique prefix, as with short git hashes) to one asset version.
  class AssetVersionResolver
    MIN_PREFIX_LENGTH = 4

    def initialize(external_id:, vcs: nil)
      @external_id = external_id.strip
      @vcs = vcs&.strip&.downcase
    end

    def call
      exact = scope.find_by(external_id: @external_id)
      return exact if exact

      candidates = prefix_candidates
      raise NotFoundError, "Asset version not found: #{@external_id}" if candidates.empty?
      if candidates.size > 1
        raise ValidationError,
              "Ambiguous prefix #{@external_id}: matches #{candidates.size} asset versions"
      end

      candidates.first
    end

    private

    def scope
      base = Models::AssetVersion.includes(:vcs_system)
      @vcs ? base.joins(:vcs_system).where(vcs_systems: { name: @vcs }) : base
    end

    def prefix_candidates
      return [] if @external_id.length < MIN_PREFIX_LENGTH

      pattern = "#{Models::AssetVersion.sanitize_sql_like(@external_id)}%"
      scope.where("asset_versions.external_id LIKE ?", pattern).limit(2).to_a
    end
  end
end
