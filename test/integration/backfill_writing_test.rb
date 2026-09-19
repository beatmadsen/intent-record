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

  # The regex is never right the first time. Seeing which subjects matched
  # nothing is how a person finds the second convention their team used, so a
  # dry run shows them rather than only counting them.
  def test_a_dry_run_shows_the_subjects_that_matched_nothing
    report = backfill([commit, commit(hash: TYPO_HASH, message: "Fix a typo\n\nbody")], dry_run: true)

    assert_equal ["Fix a typo"], report["unmatched"]
  end

  def test_a_dry_run_shows_the_sources_it_would_create
    report = backfill([commit], dry_run: true)

    assert_equal ["https://acme.atlassian.net/browse/ACME-42"], report["sources"]
  end

  # Counting them is not showing them, and a real history has thousands.
  def test_the_unmatched_list_is_capped_so_a_real_history_stays_readable
    many = Array.new(Backfill::UNMATCHED_SHOWN + 10) { |i| commit(hash: TYPO_HASH, message: "no key #{i}") }
    report = backfill(many, dry_run: true)

    assert_equal Backfill::UNMATCHED_SHOWN, report["unmatched"].size
  end

  # A commit that already has a record matched the pattern, so it is not an
  # example of the pattern missing and must not be offered as one.
  def test_an_already_recorded_commit_is_not_listed_as_unmatched
    backfill([commit])
    report = backfill([commit], dry_run: true)

    assert_empty report["unmatched"]
  end

  # A dry run reporting a source it would not in fact create would send someone
  # looking for a row that never appears.
  def test_a_dry_run_does_not_offer_sources_for_commits_it_would_skip
    backfill([commit])
    report = backfill([commit], dry_run: true)

    assert_empty report["sources"]
  end

  # A write run is not an inspection, and the list would drown the result.
  def test_a_write_run_does_not_carry_the_unmatched_list
    report = backfill([commit(hash: TYPO_HASH, message: "Fix a typo")])

    refute report.key?("unmatched")
  end

  def test_the_commit_author_is_carried_onto_the_record
    backfill([commit(author: "Dana")])

    assert_equal "Dana", Intent.sole.author
  end

  # Successive commits for one ticket are almost always a chain, and linking
  # them is what makes `show` on any one of them tell the story rather than
  # present an isolated record.
  SECOND_HASH = "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e".freeze

  def test_the_next_commit_for_a_ticket_links_back_to_the_one_before
    backfill([commit, commit(hash: SECOND_HASH, message: "ACME-42 Raise the timeout")])

    second = Intent.find_by!(summary: "ACME-42 Raise the timeout")
    assert_equal(["ACME-42 Retry flaky fetches"], second.outgoing_links.map { |l| l.target.summary })
  end

  def test_the_first_commit_for_a_ticket_links_to_nothing
    backfill([commit, commit(hash: SECOND_HASH, message: "ACME-42 Raise the timeout")])

    first = Intent.find_by!(summary: "ACME-42 Retry flaky fetches")
    assert_empty first.outgoing_links
  end

  # The most recent one only. With two commits the newest and the oldest
  # predecessor are the same record, so the rule needs a third to be visible at
  # all: the last of three must link to the second, never back to the first.
  THIRD_HASH = "fedcba9876543210fedcba9876543210fedcba98".freeze

  def test_a_third_commit_links_to_the_second_rather_than_the_first
    backfill([commit,
              commit(hash: SECOND_HASH, message: "ACME-42 Raise the timeout"),
              commit(hash: THIRD_HASH, message: "ACME-42 Log the retries")])

    third = Intent.find_by!(summary: "ACME-42 Log the retries")
    assert_equal(["ACME-42 Raise the timeout"], third.outgoing_links.map { |l| l.target.summary })
  end

  # Two tickets are two chains. Linking across them would assert a relationship
  # nothing in the history supports.
  def test_commits_for_different_tickets_are_not_linked_to_each_other
    backfill([commit, commit(hash: SECOND_HASH, message: "ACME-99 Something else")])

    other = Intent.find_by!(summary: "ACME-99 Something else")
    assert_empty other.outgoing_links
  end

  # A second run continues the chain rather than starting a new one.
  def test_a_later_run_links_onto_the_chain_the_earlier_run_left
    backfill([commit])
    backfill([commit(hash: SECOND_HASH, message: "ACME-42 Raise the timeout")])

    second = Intent.find_by!(summary: "ACME-42 Raise the timeout")
    assert_equal(["ACME-42 Retry flaky fetches"], second.outgoing_links.map { |l| l.target.summary })
  end

  # The ticket is often only in the branch name, never in the message.
  def test_a_ticket_named_only_in_the_ref_is_found
    backfill([commit(message: "Retry flaky fetches", ref: "feature/ACME-42-retry")])

    assert_equal "https://acme.atlassian.net/browse/ACME-42", Intent.sole.stakeholder_sources.sole.uri
  end
end
