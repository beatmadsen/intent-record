require "test_helper"
require "intent_record/web/app"

class SourcesPageTest < WebAcceptanceCase
  def test_sources_page_lists_intents_for_ticket_key_substring
    jira = { "system" => "jira", "uri" => "https://j/browse/ACME-42" }
    id = record_intent!(summary: "Retry fetch", commits: [HASH], stakeholder_references: [jira])["intent_id"]

    get "/sources", uri: "ACME-42"

    assert_equal 200, last_response.status
    assert_body_includes %(href="/intents/#{id}")
    assert_body_includes %(href="/commits/#{HASH}?vcs=git")
  end

  def test_sources_page_with_no_matches_says_so
    get "/sources", uri: "ACME-999"

    assert_body_includes "No intent"
  end
end
