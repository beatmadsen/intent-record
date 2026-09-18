require "test_helper"

class RecordWithStakeholdersTest < Minitest::Test
  include IntentRecordDsl

  JIRA = { "system" => "jira", "uri" => "https://acme.atlassian.net/browse/ACME-42", "title" => "Retry flaky fetch" }.freeze

  def test_links_intent_to_stakeholder_source
    json = record_intent!(stakeholder_references: [JIRA])

    record = IntentRecord::Models::IntentRecord.find_by!(global_id: json["intent_id"])
    source = record.stakeholder_sources.sole
    assert_equal JIRA["uri"], source.uri
    assert_equal "Retry flaky fetch", source.title
    assert_equal "jira", source.stakeholder_system.name
  end

  def test_same_uri_in_same_system_is_deduplicated
    record_intent!(stakeholder_references: [JIRA])
    record_intent!(stakeholder_references: [JIRA.merge("title" => nil)])

    assert_equal 1, IntentRecord::Models::StakeholderSource.count
  end

  def test_rejects_reference_without_system
    result = run_cli("record", stdin: { "summary" => "s", "body" => "b",
                                        "stakeholder_references" => [{ "uri" => "https://x" }] })

    assert_cli_rejected result, matching: /system/
  end
end
