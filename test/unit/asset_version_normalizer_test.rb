require "test_helper"

class AssetVersionNormalizerTest < Minitest::Test
  N = IntentRecord::AssetVersionNormalizer
  SHA1 = "abc1234abc1234abc1234abc1234abc1234abc12".freeze

  def test_a_vcs_name_is_stripped_and_lowercased
    assert_equal "git", N.vcs_name("  GIT \n")
  end

  def test_a_hash_based_system_is_recognised
    assert N.hash_based?("mercurial")
  end

  def test_a_system_that_is_not_hash_based_is_not
    refute N.hash_based?("perforce")
  end

  def test_an_id_is_stripped
    assert_equal SHA1, N.external_id("git", "  #{SHA1}  ")
  end

  def test_an_id_for_a_hash_based_system_is_stored_lowercase
    assert_equal SHA1, N.external_id("git", SHA1.upcase)
  end

  # Perforce changelists and Subversion revisions are not hashes, and their case
  # is part of the id rather than an accident of how someone typed it.
  def test_an_id_for_a_case_sensitive_system_keeps_its_case
    assert_equal "ABC123", N.external_id("perforce", " ABC123 ")
  end

  def test_a_git_id_that_is_not_a_full_hash_is_rejected
    error = assert_raises(IntentRecord::ValidationError) { N.external_id("git", "abc1234") }

    assert_match(/40 or 64 hex characters/, error.message)
  end

  def test_a_git_id_may_be_a_sha256_hash
    id = "a" * 64

    assert_equal id, N.external_id("git", id)
  end

  # Only git is checked for shape. The other hash-based systems take an id as
  # given, so tightening external_id to validate all of HASH_BASED would change
  # behaviour rather than fix an oversight, and would reject ids already stored.
  # Ambiguity among loose ids is caught by the resolver at lookup time instead.
  def test_a_hash_based_system_other_than_git_takes_an_id_that_is_not_a_hash
    assert_equal "zzz", N.external_id("mercurial", "ZZZ")
  end

  # This is the decision the source said no test could tell apart from leaving
  # the id alone. Nothing driving the CLI can, because the resolver also tries
  # the id as written and SQLite's LIKE folds ASCII case anyway. Asked directly,
  # it decides.
  def test_a_lookup_id_is_lowercased_for_a_hash_based_system
    assert_equal SHA1, N.lookup_id("git", SHA1.upcase)
  end

  # With no system named the id could belong to either kind, and the resolver
  # tries both spellings, so this one is the lowercased candidate.
  def test_a_lookup_id_is_lowercased_when_no_system_is_named
    assert_equal SHA1, N.lookup_id(nil, SHA1.upcase)
  end

  def test_a_lookup_id_for_a_case_sensitive_system_keeps_its_case
    assert_equal "ABC123", N.lookup_id("perforce", " ABC123 ")
  end
end
