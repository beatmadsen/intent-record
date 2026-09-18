require "test_helper"
require "intent_record/web/app"

class IntentPageTest < WebAcceptanceCase
  def test_intent_page_shows_the_summary_and_body
    id = record_intent!(summary: "Follow-up", body: "Builds on earlier.")["intent_id"]

    get "/intents/#{id}"

    assert_equal 200, last_response.status
    assert_body_includes "Follow-up"
    assert_body_includes "Builds on earlier."
  end

  def test_intent_page_links_to_each_commit_it_records
    id = record_intent!(commits: [HASH])["intent_id"]

    get "/intents/#{id}"

    assert_body_includes %(href="/commits/#{HASH}?vcs=git")
  end

  def test_intent_page_links_to_each_related_intent_under_its_summary
    earlier = record_intent!(summary: "Earlier work")["intent_id"]
    id = record_intent!(related_intent_ids: [earlier])["intent_id"]

    get "/intents/#{id}"

    assert_body_includes %(href="/intents/#{earlier}")
    assert_body_includes "Earlier work"
  end

  def test_unknown_intent_is_not_found
    get "/intents/zzzzzzz"

    assert_equal 404, last_response.status
  end
end
