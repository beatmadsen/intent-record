require "test_helper"

# Reading the payload is separate from writing the links, and it is the half
# with decisions in it, so it is asked directly rather than through a database.
class AssetVersionSpecsTest < Minitest::Test
  S = IntentRecord::Linkers::AssetVersionSpecs
  SHA1 = "abc1234abc1234abc1234abc1234abc1234abc12".freeze

  def test_no_asset_version_keys_at_all_gives_nothing_to_link
    assert_empty S.from({})
  end

  def test_a_commit_is_shorthand_for_a_git_asset_version
    assert_equal [["git", SHA1]], S.from("commits" => [SHA1])
  end

  def test_an_explicit_asset_version_keeps_the_system_it_names
    input = { "asset_versions" => [{ "vcs" => "perforce", "external_id" => "12345" }] }

    assert_equal [%w[perforce 12345]], S.from(input)
  end

  def test_commits_come_before_explicit_asset_versions
    input = { "commits" => [SHA1], "asset_versions" => [{ "vcs" => "perforce", "external_id" => "1" }] }

    assert_equal [["git", SHA1], %w[perforce 1]], S.from(input)
  end

  def test_a_blank_commit_is_rejected_and_named_as_a_commit
    error = assert_raises(IntentRecord::ValidationError) { S.from("commits" => [SHA1, " "]) }

    assert_match(/commit must be a non-empty string/, error.message)
  end

  def test_commits_that_are_not_an_array_are_rejected
    error = assert_raises(IntentRecord::ValidationError) { S.from("commits" => SHA1) }

    assert_match(/commits must be an array/, error.message)
  end

  def test_an_asset_version_missing_its_system_is_rejected
    error = assert_raises(IntentRecord::ValidationError) do
      S.from("asset_versions" => [{ "external_id" => "1" }])
    end

    assert_match(/vcs is required/, error.message)
  end

  def test_an_asset_version_missing_its_id_is_rejected
    error = assert_raises(IntentRecord::ValidationError) do
      S.from("asset_versions" => [{ "vcs" => "perforce" }])
    end

    assert_match(/external_id is required/, error.message)
  end

  def test_an_asset_version_that_is_not_an_object_is_rejected
    error = assert_raises(IntentRecord::ValidationError) { S.from("asset_versions" => ["nope"]) }

    assert_match(/asset_versions entries must be objects/, error.message)
  end

  # Every entry is read before any of them is linked, so a payload with a bad
  # second entry never reaches the database at all.
  def test_a_later_bad_entry_is_found_before_anything_is_returned
    assert_raises(IntentRecord::ValidationError) { S.from("commits" => [SHA1], "asset_versions" => ["nope"]) }
  end
end
