require "test_helper"

# The invariant says database ids never leave the database. A record with nothing
# linked to it is the one shape where that is true by accident, so these use the
# richest responses the CLI can produce.
class NoInternalIdsTest < Minitest::Test
  include IntentRecordDsl

  HASH = "abc1234abc1234abc1234abc1234abc1234abc12".freeze
  JIRA = { "system" => "jira", "uri" => "https://acme.atlassian.net/browse/ACME-42", "title" => "Retry" }.freeze

  def test_an_intent_with_every_kind_of_link_exposes_none
    assert_no_internal_ids run_cli_ok!("show", fully_linked_intent)
  end

  def test_a_stakeholder_source_answer_exposes_none
    fully_linked_intent

    assert_no_internal_ids run_cli_ok!("by-source", JIRA["uri"])
  end

  def test_a_commit_lookup_exposes_none
    fully_linked_intent

    assert_no_internal_ids run_cli_ok!("lookup", HASH)
  end

  private

  # Links in both directions, plus a commit and a stakeholder source, so every
  # shape Formatter can emit is present in the answer.
  def fully_linked_intent
    earlier = record_intent!(summary: "earlier")["intent_id"]
    subject = record_intent!(summary: "subject", commits: [HASH], stakeholder_references: [JIRA],
                             related_intent_ids: [earlier])["intent_id"]
    later = record_intent!(summary: "later")["intent_id"]
    run_cli_ok!("attach", later, stdin: { "related_intent_ids" => [subject] })
    subject
  end
end
