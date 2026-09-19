require "test_helper"

# What backfill writes, asked of the command rather than through the CLI. The
# matching rules are ReferenceScanner's and the wording is BackfilledIntent's;
# what is left here is which commits get a record and which are passed over.
class BackfillWritingTest < Minitest::Test
  include DbTestSetup

  Backfill = IntentRecord::Commands::Backfill
  Intent = IntentRecord::Models::IntentRecord

  RETRY_HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze
  TYPO_HASH = "0123456789abcdef0123456789abcdef01234567".freeze

  def backfill(commits, **)
    Backfill.new(system: "jira", pattern: 'ACME-\d+',
                 uri_prefix: "https://acme.atlassian.net/browse/", **)
            .call({ "commits" => commits })
  end

  def commit(hash: RETRY_HASH, message: "ACME-42 Retry flaky fetches", **rest)
    { "commit" => hash, "message" => message }.merge(rest.transform_keys(&:to_s))
  end

  def test_a_commit_naming_a_ticket_gets_a_record
    backfill([commit])

    assert_equal 1, Intent.count
  end

  def test_a_commit_naming_nothing_gets_no_record
    backfill([commit(hash: TYPO_HASH, message: "Fix a typo")])

    assert_equal 0, Intent.count
  end

  def test_the_record_is_linked_to_its_commit
    backfill([commit])

    assert_equal RETRY_HASH, Intent.sole.asset_versions.sole.external_id
  end

  def test_the_record_is_linked_to_the_ticket_the_message_named
    backfill([commit])

    assert_equal "https://acme.atlassian.net/browse/ACME-42", Intent.sole.stakeholder_sources.sole.uri
  end

  # Running it twice is how a person finds their second key convention, so it
  # has to be cheap rather than doubling every record.
  def test_running_it_again_writes_nothing_further
    backfill([commit])
    backfill([commit])

    assert_equal 1, Intent.count
  end

  def test_it_reports_what_it_created_and_passed_over
    report = backfill([commit, commit(hash: TYPO_HASH, message: "Fix a typo")])

    assert_equal({ "created" => 1, "skipped" => 1, "failed" => 0 }, report.slice("created", "skipped", "failed"))
  end

  def test_a_commit_that_already_has_an_intent_is_reported_as_skipped
    backfill([commit])
    report = backfill([commit])

    assert_equal 1, report["skipped"]
  end

  # One malformed hash in a history of thousands must not cost the whole run.
  def test_a_commit_that_cannot_be_written_is_reported_without_losing_the_rest
    report = backfill([commit(hash: "not-a-hash"), commit])

    assert_equal [1, 1], [report["created"], report["failed"]]
    assert_equal 1, Intent.count
  end

  def test_a_failed_commit_is_named_with_its_reason
    report = backfill([commit(hash: "not-a-hash")])

    failure = report["failures"].sole
    assert_equal "not-a-hash", failure["commit"]
    assert_match(/hex/, failure["error"])
  end

  # A dry run is how someone checks their regex before it writes anything.
  def test_a_dry_run_reports_what_it_would_do_and_writes_nothing
    report = backfill([commit], dry_run: true)

    assert_equal 1, report["created"]
    assert_equal 0, Intent.count
  end

  def test_the_commit_author_is_carried_onto_the_record
    backfill([commit(author: "Dana")])

    assert_equal "Dana", Intent.sole.author
  end

  # The ticket is often only in the branch name, never in the message.
  def test_a_ticket_named_only_in_the_ref_is_found
    backfill([commit(message: "Retry flaky fetches", ref: "feature/ACME-42-retry")])

    assert_equal "https://acme.atlassian.net/browse/ACME-42", Intent.sole.stakeholder_sources.sole.uri
  end
end
