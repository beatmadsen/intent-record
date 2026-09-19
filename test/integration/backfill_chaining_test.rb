require "test_helper"

# Successive commits for one ticket are a chain, and the link is what makes
# `show` on any one of them tell the story rather than present an isolated
# record.
class BackfillChainingTest < Minitest::Test
  include DbTestSetup
  include BackfillDsl

  def timeout_commit(hash: SECOND_HASH)
    commit(hash: hash, message: TIMEOUT_SUBJECT)
  end

  def logging_commit
    commit(hash: THIRD_HASH, message: LOGGING_SUBJECT)
  end

  def test_the_next_commit_for_a_ticket_links_back_to_the_one_before
    backfill([commit, timeout_commit], order: "oldest-first")

    assert_equal [RETRY_SUBJECT], builds_on(TIMEOUT_SUBJECT)
  end

  def test_the_first_commit_for_a_ticket_links_to_nothing
    backfill([commit, timeout_commit], order: "oldest-first")

    assert_empty builds_on(RETRY_SUBJECT)
  end

  # The most recent predecessor only. With two commits the newest and the
  # oldest are the same record, so the rule needs a third to be visible: the
  # last of three links to the second, never back to the first.
  def test_a_third_commit_links_to_the_second_rather_than_the_first
    backfill([commit, timeout_commit, logging_commit], order: "oldest-first")

    assert_equal [TIMEOUT_SUBJECT], builds_on(LOGGING_SUBJECT)
  end

  # `git log` prints newest first, which is what a person pipes in, and the
  # chain must still run oldest to newest. Fed that way the naive link points
  # backwards, which is what this pins.
  def test_a_history_given_newest_first_still_chains_oldest_to_newest
    backfill([logging_commit, timeout_commit, commit])

    assert_equal [TIMEOUT_SUBJECT], builds_on(LOGGING_SUBJECT)
    assert_equal [RETRY_SUBJECT], builds_on(TIMEOUT_SUBJECT)
  end

  def test_the_oldest_commit_of_a_newest_first_history_links_to_nothing
    backfill([timeout_commit, commit])

    assert_empty builds_on(RETRY_SUBJECT)
  end

  # Two tickets are two chains. Linking across them would assert a relationship
  # nothing in the history supports.
  def test_commits_for_different_tickets_are_not_linked_to_each_other
    backfill([commit, commit(hash: SECOND_HASH, message: "ACME-99 Something else")])

    assert_empty builds_on("ACME-99 Something else")
  end

  # The predecessor is asked of the store, so a later run continues the chain
  # rather than starting a parallel one.
  def test_a_later_run_links_onto_the_chain_the_earlier_run_left
    backfill([commit])
    backfill([timeout_commit])

    assert_equal [RETRY_SUBJECT], builds_on(TIMEOUT_SUBJECT)
  end
end
