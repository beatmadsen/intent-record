require_relative "models/asset_version"
require_relative "models/vcs_system"
require_relative "asset_version_normalizer"
require_relative "like_pattern"

module IntentRecord
  # Resolves an external id to one asset version. Exact match first; for hash-based VCSs a
  # unique prefix of at least MIN_PREFIX_LENGTH characters also resolves.
  class AssetVersionResolver
    MIN_PREFIX_LENGTH = 4

    def initialize(external_id:, vcs: nil)
      @vcs = vcs && AssetVersionNormalizer.vcs_name(vcs)
      @external_id = AssetVersionNormalizer.lookup_id(@vcs, external_id)
    end

    def call
      exact = scope.find_by(external_id: @external_id) || scope.find_by(external_id: @external_id.downcase)
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
      base = Models::AssetVersion.includes(:vcs_system).joins(:vcs_system)
      @vcs ? base.where(vcs_systems: { name: @vcs }) : base
    end

    def prefix_candidates
      return [] if @external_id.length < MIN_PREFIX_LENGTH

      scope.where(vcs_systems: { name: AssetVersionNormalizer::HASH_BASED })
           .where(LikePattern.prefix("asset_versions.external_id"), LikePattern.prefix_bind(@external_id.downcase))
           .to_a
    end
  end
end
