require "test_helper"

# The source and title rules are StakeholderLinker's, so they are asked of it
# rather than through the CLI. RecordWithStakeholdersTest keeps one end-to-end
# case to show the command reaches this at all.
class StakeholderLinkingTest < Minitest::Test
  include DbTestSetup

  Source = IntentRecord::Models::StakeholderSource
  TICKET = "https://acme.atlassian.net/browse/ACME-42".freeze
  JIRA = { "system" => "jira", "uri" => TICKET, "title" => "Retry flaky fetch" }.freeze

  def test_a_reference_stores_the_system_uri_and_title
    link(JIRA)

    assert_equal ["jira", TICKET, "Retry flaky fetch"],
                 [Source.sole.stakeholder_system.name, Source.sole.uri, Source.sole.title]
  end

  def test_the_same_uri_in_the_same_system_is_one_source
    link(JIRA)
    link(JIRA)

    assert_equal 1, Source.count
  end

  # The other half of uniqueness being per (system, uri): the same ticket
  # referenced under two systems is two sources, not one shared row.
  def test_the_same_uri_in_another_system_is_a_second_source
    link(JIRA)
    link(JIRA.merge("system" => "confluence"))

    assert_equal 2, Source.count
  end

  def test_a_later_title_replaces_the_stored_one
    link(JIRA)
    link(JIRA.merge("title" => "Retry with backoff"))

    assert_equal "Retry with backoff", Source.sole.title
  end

  def test_a_missing_title_leaves_the_stored_one
    link(JIRA)
    link(JIRA.except("title"))

    assert_equal "Retry flaky fetch", Source.sole.title
  end

  # A blank title reaches a different branch from a missing one: it is read as
  # absent rather than as an instruction to store nothing.
  def test_a_blank_title_leaves_the_stored_one
    link(JIRA)
    link(JIRA.merge("title" => "   "))

    assert_equal "Retry flaky fetch", Source.sole.title
  end

  # The consequence of the two above, worth stating because nothing else does:
  # once a source has a title, no payload can take it away again.
  def test_an_explicit_null_title_cannot_clear_a_stored_one
    link(JIRA)
    link(JIRA.merge("title" => nil))

    assert_equal "Retry flaky fetch", Source.sole.title
  end

  def test_a_source_may_be_created_without_a_title
    link(JIRA.except("title"))

    assert_nil Source.sole.title
  end

  def test_a_title_that_is_not_a_string_is_rejected
    error = assert_raises(IntentRecord::ValidationError) { link(JIRA.merge("title" => 7)) }

    assert_match(/title must be a string/, error.message)
  end

  # The linker answers once per entry in the payload, so the duplication to look
  # for is in the rows, not in what it returns.
  def test_one_payload_naming_a_source_twice_stores_one_source
    link(JIRA, JIRA.merge("title" => "Second"))

    assert_equal 1, Source.count
  end

  def test_one_payload_naming_a_source_twice_stores_one_reference
    link(JIRA, JIRA.merge("title" => "Second"))

    assert_equal 1, IntentRecord::Models::StakeholderReference.count
  end

  def test_the_last_title_in_a_payload_is_the_one_stored
    link(JIRA, JIRA.merge("title" => "Second"))

    assert_equal "Second", Source.sole.title
  end

  private

  def link(*refs)
    record = IntentRecord::Models::IntentRecord.create!(
      global_id: IntentRecord::GlobalId.unique_for(IntentRecord::Models::IntentRecord),
      summary: "s", body: "b", created_at: Time.now.utc
    )
    IntentRecord::Linkers::StakeholderLinker.call(record, "stakeholder_references" => refs)
  end
end
