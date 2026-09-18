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
      @raw = external_id.strip
      @external_id = AssetVersionNormalizer.lookup_id(@vcs, external_id)
    end

    def call
      exact_match || resolve_prefix
    end

    private

    # With no vcs given the id could belong to a hash-based system, where case is
    # insignificant, or to a case-sensitive one, where it is not, so both spellings
    # are candidates. When a vcs is given the normaliser has already picked the one
    # that system uses.
    def exact_candidates
      @vcs ? [@external_id] : [@raw, @external_id].uniq
    end

    # Ids are unique per version control system, not across them, so one spelling
    # can name two different things. Answering with either of them would be
    # SQLite's choice, and it would hide everything recorded against the other,
    # so say so instead and let the caller name the system.
    def exact_match
      exact_candidates.each do |id|
        found = scope.where(external_id: id).to_a
        next if found.empty?
        raise ValidationError, ambiguous(id, found.size) if found.size > 1

        return found.first
      end
      nil
    end

    def ambiguous(id, count)
      "Ambiguous id #{id}: matches #{count} asset versions in different " \
        "version control systems. Name one with --vcs."
    end

    def resolve_prefix
      candidates = prefix_candidates
      raise NotFoundError, "Asset version not found: #{@external_id}" if candidates.empty?
      if candidates.size > 1
        raise ValidationError,
              "Ambiguous prefix #{@external_id}: matches #{candidates.size} asset versions"
      end

      candidates.first
    end

    def scope
      base = Models::AssetVersion.includes(:vcs_system).joins(:vcs_system)
      @vcs ? base.where(vcs_systems: { name: @vcs }) : base
    end

    def prefix_candidates
      return [] if @external_id.length < MIN_PREFIX_LENGTH

      scope.where(vcs_systems: { name: AssetVersionNormalizer::HASH_BASED })
           .where(LikePattern.prefix("asset_versions.external_id"), LikePattern.prefix_bind(@external_id))
           .to_a
    end
  end
end
