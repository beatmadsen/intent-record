require "test_helper"

class AssetVersionResolverTest < Minitest::Test
  include DbTestSetup

  FULL = "abcdef0123456789abcdef0123456789abcdef01".freeze

  def resolve(id, vcs: nil)
    IntentRecord::AssetVersionResolver.new(external_id: id, vcs: vcs).call
  end

  def seed(external_id, vcs: "git")
    system = IntentRecord::Models::VcsSystem.find_or_create_by!(name: vcs) { |s| s.created_at = Time.now.utc }
    IntentRecord::Models::AssetVersion.create!(vcs_system: system, external_id: external_id, created_at: Time.now.utc)
  end

  def test_exact_match_wins_over_prefix_match
    seed("abcd")
    seed("abcdef")

    assert_equal "abcd", resolve("abcd").external_id
  end

  def test_prefix_shorter_than_minimum_is_not_found
    seed(FULL)

    assert_raises(IntentRecord::NotFoundError) { resolve("abc") }
  end

  def test_prefix_of_exactly_the_minimum_length_resolves
    seed(FULL)

    assert_equal FULL, resolve(FULL[0, IntentRecord::AssetVersionResolver::MIN_PREFIX_LENGTH]).external_id
  end

  # Resolves through the prefix query, whose LIKE is case-insensitive for ASCII,
  # so this pins the outcome a user sees rather than the downcasing that precedes it.
  def test_an_uppercase_hash_resolves_when_no_vcs_is_given
    seed(FULL)

    assert_equal FULL, resolve(FULL.upcase).external_id
  end

  # Without --vcs the id could belong to either family. Downcasing it on the way in
  # put a case-sensitive id out of reach of every lookup that omitted the flag.
  def test_a_case_sensitive_id_resolves_without_a_vcs_filter
    seed("ABC123", vcs: "perforce")

    assert_equal "ABC123", resolve("ABC123").external_id
  end

  def test_like_wildcards_in_input_are_literal
    seed(FULL)

    assert_raises(IntentRecord::NotFoundError) { resolve("%bcd") }
  end

  def test_id_of_a_case_sensitive_vcs_does_not_match_a_differently_cased_id
    seed("abc123", vcs: "perforce")

    assert_raises(IntentRecord::NotFoundError) { resolve("ABC123", vcs: "perforce") }
  end

  def test_vcs_filter_is_case_insensitive
    seed("123", vcs: "perforce")

    assert_equal "123", resolve("123", vcs: "Perforce").external_id
  end
end
