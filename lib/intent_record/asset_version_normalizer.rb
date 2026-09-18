module IntentRecord
  # Normalises external ids per VCS. Hash-based systems get lowercase hex ids and support
  # prefix lookup; git ids must be full SHA-1 or SHA-256 hashes so prefixes stay unambiguous.
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

    # No test can currently tell this downcasing apart from leaving the id alone:
    # the resolver tries the id as written too, and sqlite's LIKE is case-insensitive
    # for ASCII, so the prefix path finds a hash whatever its case. It stays because
    # hash ids are canonically lowercase here, and that should not depend on a
    # collation default we do not set.
    def lookup_id(vcs, raw)
      id = raw.strip
      vcs.nil? || hash_based?(vcs) ? id.downcase : id
    end
  end
end
