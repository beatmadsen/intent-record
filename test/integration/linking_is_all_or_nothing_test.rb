require "test_helper"

# AssetVersionSpecs checks the payload before anything is written, but a git id
# is checked for shape while it is being linked, so the second of two commits
# can fail after the first has already been stored. Both commands wrap the
# linking in a transaction for that reason, and nothing said so until now.
class LinkingIsAllOrNothingTest < Minitest::Test
  include DbTestSetup

  Models = IntentRecord::Models
  GOOD = ("a" * 40).freeze
  ALSO_GOOD = ("b" * 40).freeze
  MALFORMED = "nope".freeze

  def test_a_record_whose_second_commit_is_malformed_stores_no_record
    refuses { record("commits" => [GOOD, MALFORMED]) }

    assert_equal 0, Models::IntentRecord.count
  end

  def test_a_record_whose_second_commit_is_malformed_stores_no_asset_version
    refuses { record("commits" => [GOOD, MALFORMED]) }

    assert_equal 0, Models::AssetVersion.count
  end

  def test_an_attach_whose_second_commit_is_malformed_adds_no_asset_version
    id = record("commits" => [GOOD])["intent_id"]

    refuses { IntentRecord::Commands::Attach.new(intent_id: id).call("commits" => [ALSO_GOOD, MALFORMED]) }

    assert_equal [GOOD], Models::AssetVersion.pluck(:external_id)
  end

  # Without this the three above would also pass against a linker that stored
  # nothing at all, so the measurement has to be shown capable of storing both.
  def test_two_sound_commits_are_both_stored
    record("commits" => [GOOD, ALSO_GOOD])

    assert_equal [GOOD, ALSO_GOOD], Models::AssetVersion.order(:id).pluck(:external_id)
  end

  private

  def record(input)
    IntentRecord::Commands::Record.new.call({ "summary" => "s", "body" => "b" }.merge(input))
  end

  def refuses(&)
    assert_raises(IntentRecord::ValidationError, &)
  end
end
