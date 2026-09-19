require "test_helper"

# The text a backfilled record carries. A commit message says what changed, not
# why, so the record says plainly that the reasoning was never recorded, and
# leaves the agent that next touches this code somewhere to attach the real one.
class BackfilledIntentTest < Minitest::Test
  Intent = IntentRecord::Backfill::BackfilledIntent

  def intent_for(message, author: "Dana")
    Intent.new(message: message, author: author).to_h
  end

  def test_summary_is_the_subject_line
    built = intent_for("ACME-42 Retry flaky fetches\n\nCI went red three times.")

    assert_equal "ACME-42 Retry flaky fetches", built["summary"]
  end

  def test_body_opens_by_saying_the_reasoning_was_not_recorded
    built = intent_for("ACME-42 Retry flaky fetches\n\nCI went red three times.")

    assert_equal Intent::MARKER, built["body"].lines.first.strip
  end

  def test_body_keeps_the_rest_of_the_commit_message
    built = intent_for("ACME-42 Retry flaky fetches\n\nCI went red three times.")

    assert_includes built["body"], "CI went red three times."
  end

  # The store has to answer without the repo: no repository identity is kept, so
  # a body pointing at git names no git anyone could open.
  def test_body_carries_the_subject_too_so_the_store_answers_without_the_repo
    built = intent_for("ACME-42 Retry flaky fetches\n\nCI went red three times.")

    assert_includes built["body"], "ACME-42 Retry flaky fetches"
  end

  def test_a_one_line_message_still_yields_a_body
    built = intent_for("Fix the typo")

    refute_predicate built["body"].strip, :empty?
  end

  def test_the_commit_author_is_carried_over
    assert_equal "Dana", intent_for("m")["author"]
  end

  # summary is capped, and a commit subject has no such limit.
  def test_an_overlong_subject_is_truncated_to_fit_the_summary
    limit = IntentRecord::Models::IntentRecord::SUMMARY_MAX_LENGTH
    built = intent_for("#{"x" * (limit + 50)}\n\nbody")

    assert_operator built["summary"].length, :<=, limit
  end

  def test_an_overlong_subject_survives_in_full_in_the_body
    limit = IntentRecord::Models::IntentRecord::SUMMARY_MAX_LENGTH
    subject = "y" * (limit + 50)

    assert_includes intent_for("#{subject}\n\nbody")["body"], subject
  end

  # A message that is only whitespace would otherwise produce a blank summary,
  # which record refuses, failing the whole run over one empty commit message.
  def test_a_blank_message_still_yields_a_usable_summary
    built = intent_for("   \n\n  ")

    refute_predicate built["summary"].strip, :empty?
  end
end
