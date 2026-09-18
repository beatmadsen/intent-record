require "test_helper"

class CommitHashNormalisationTest < Minitest::Test
  include IntentRecordDsl

  UPPER = "ABCDEF1234567890ABCDEF1234567890ABCDEF12".freeze

  def test_the_same_hash_in_two_cases_is_one_asset_version
    record_intent!(commits: [UPPER])
    record_intent!(commits: [UPPER.downcase])

    assert_equal 1, IntentRecord::Models::AssetVersion.count
  end

  def test_both_intents_are_found_by_a_prefix_of_that_hash
    record_intent!(commits: [UPPER])
    record_intent!(commits: [UPPER.downcase])

    assert_equal 2, run_cli_ok!("lookup", UPPER[0, 12])["intents"].size
  end

  def test_a_git_hash_that_is_not_full_length_hex_is_rejected
    result = run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => ["zzz"] })

    assert_cli_rejected result, matching: /40 or 64 hex/
  end

  def test_a_full_sha256_hash_is_accepted
    assert_cli_ok run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => ["a" * 64] })
  end

  def test_a_prefix_does_not_resolve_for_a_vcs_that_is_not_hash_based
    record_intent!(asset_versions: [{ "vcs" => "perforce", "external_id" => "12345" }])

    assert_cli_rejected run_cli("lookup", "1234"), matching: /not found/i
  end

  def test_the_whole_id_still_resolves_for_a_vcs_that_is_not_hash_based
    record_intent!(asset_versions: [{ "vcs" => "perforce", "external_id" => "12345" }])

    assert_cli_ok run_cli("lookup", "12345")
  end

  def test_an_ambiguous_prefix_says_how_many_it_matched
    3.times { |i| record_intent!(commits: ["abcdef#{i}#{"0" * 33}"]) }

    assert_cli_rejected run_cli("lookup", "abcdef"), matching: /matches 3 asset versions/
  end
end
