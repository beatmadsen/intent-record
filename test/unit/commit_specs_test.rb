require "test_helper"

# What a backfill payload says about each commit, checked before any of it is
# written. Every entry is judged before the first is returned, so a payload with
# a bad entry late in the list never reaches the database.
class CommitSpecsTest < Minitest::Test
  Specs = IntentRecord::Backfill::CommitSpecs

  HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze

  def test_reads_a_commit_with_its_message_and_author
    read = Specs.from({ "commits" => [{ "commit" => HASH, "author" => "Dana", "message" => "ACME-42 Retry" }] })

    assert_equal [{ commit: HASH, author: "Dana", message: "ACME-42 Retry", ref: nil }], read
  end

  # A list of bare hashes rather than objects is a plausible mistake, and
  # reading one as a commit would fail somewhere less legible later.
  def test_rejects_an_entry_that_is_not_an_object
    error = assert_raises(IntentRecord::ValidationError) { Specs.from({ "commits" => [HASH] }) }

    assert_match(/object/, error.message)
  end

  def test_rejects_a_payload_whose_commits_is_not_an_array
    assert_raises(IntentRecord::ValidationError) { Specs.from({ "commits" => "nope" }) }
  end

  def test_rejects_an_entry_that_names_no_commit
    error = assert_raises(IntentRecord::ValidationError) { Specs.from({ "commits" => [{ "message" => "m" }] }) }

    assert_match(/commit/, error.message)
  end

  # An empty commit message is rare and real, and it names no ticket, so it is
  # the same as any commit that matches nothing. Refusing it here would abort a
  # whole history over one commit nobody wrote a message for.
  def test_an_entry_with_no_message_is_read_as_an_empty_one
    read = Specs.from({ "commits" => [{ "commit" => HASH }] })

    assert_equal "", read.sole[:message]
  end

  def test_an_entry_whose_message_is_only_whitespace_is_read_as_empty
    read = Specs.from({ "commits" => [{ "commit" => HASH, "message" => "   \n " }] })

    assert_equal "", read.sole[:message]
  end

  def test_a_message_that_is_not_a_string_is_still_refused
    payload = { "commits" => [{ "commit" => HASH, "message" => 42 }] }

    assert_raises(IntentRecord::ValidationError) { Specs.from(payload) }
  end

  # The bad entry is second, so accepting the first and failing afterwards is
  # exactly what this refuses.
  def test_judges_every_entry_before_returning_any
    payload = { "commits" => [{ "commit" => HASH, "message" => "ACME-42 Retry" }, { "message" => "no commit" }] }

    assert_raises(IntentRecord::ValidationError) { Specs.from(payload) }
  end

  def test_an_absent_author_is_read_as_absent_rather_than_blank
    read = Specs.from({ "commits" => [{ "commit" => HASH, "message" => "m" }] })

    assert_nil read.sole[:author]
  end

  # Many teams put the ticket key in the branch and never in the message, so the
  # ref travels with the commit and the scanner is given both to read.
  def test_carries_the_ref_when_one_is_given
    read = Specs.from({ "commits" => [{ "commit" => HASH, "message" => "m", "ref" => "feature/ACME-42-retry" }] })

    assert_equal "feature/ACME-42-retry", read.sole[:ref]
  end
end
