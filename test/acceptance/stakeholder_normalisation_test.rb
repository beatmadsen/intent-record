require "test_helper"

# The title rules for a source live in record_with_stakeholders_test.rb.
class StakeholderNormalisationTest < Minitest::Test
  include IntentRecordDsl

  VARIANTS = ["https://acme.atlassian.net/browse/ACME-42",
              "https://acme.atlassian.net/browse/ACME-42/",
              "HTTPS://ACME.ATLASSIAN.NET/browse/ACME-42"].freeze

  def test_scheme_host_case_and_a_trailing_slash_make_one_source
    VARIANTS.each { |uri| record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => uri }]) }

    assert_equal 1, IntentRecord::Models::StakeholderSource.count
  end

  def test_every_intent_on_those_variants_is_found_by_any_of_them
    VARIANTS.each { |uri| record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => uri }]) }

    assert_equal 3, run_cli_ok!("by-source", VARIANTS.last)["intents"].size
  end

  def test_the_path_keeps_its_case
    record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => "https://j/browse/ACME-42" }])

    assert_equal "https://j/browse/ACME-42", IntentRecord::Models::StakeholderSource.sole.uri
  end

  def test_a_system_name_is_trimmed_lowercased_and_hyphenated
    record_intent!(stakeholder_references: [{ "system" => "  My Tracker ", "uri" => "https://t/1" }])

    assert_equal "my-tracker", IntentRecord::Models::StakeholderSystem.order(:id).last.name
  end

  def test_by_source_returns_an_empty_sources_array_when_nothing_matches
    assert_equal [], run_cli_ok!("by-source", "https://none")["sources"]
  end

  def test_by_source_returns_the_source_it_matched
    record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => "https://j/1" }])

    assert_equal 1, run_cli_ok!("by-source", "https://j/1")["sources"].size
  end
end
