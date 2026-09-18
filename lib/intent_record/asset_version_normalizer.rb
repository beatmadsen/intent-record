module IntentRecord
  # Normalises external ids per VCS. Hash-based systems store their ids lowercased and
  # support prefix lookup. Only git is checked for shape, and must be a full SHA-1 or
  # SHA-256; the other hash-based systems take an id as given, so a prefix among those
  # can collide, and the resolver reports that at lookup time rather than preventing it
  # here.
  module AssetVersionNormalizer
    HASH_BASED = %w[git mercurial fossil sapling pijul darcs].freeze
    GIT_HASH = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/

    module_function

    def vcs_name(vcs)
      vcs.strip.downcase
    end

    def hash_based?(vcs)
      HASH_BASED.include?(vcs)
    end

    def external_id(vcs, raw)
      id = raw.strip
      id = id.downcase if hash_based?(vcs)
      if vcs == "git" && !GIT_HASH.match?(id)
        raise ValidationError,
              "git commit must be 40 or 64 hex characters, got #{raw.inspect}"
      end

      id
    end

    # Hash ids are canonically lowercase here, and that should not depend on a
    # collation default we do not set. Nothing driving the CLI can tell this apart
    # from leaving the id alone, because the resolver tries the id as written too
    # and sqlite's LIKE folds ASCII case; the tests that decide it ask this
    # directly, or go through the resolver below the prefix minimum, where there
    # is no second chance from the prefix query.
    def lookup_id(vcs, raw)
      id = raw.strip
      vcs.nil? || hash_based?(vcs) ? id.downcase : id
    end
  end
end
