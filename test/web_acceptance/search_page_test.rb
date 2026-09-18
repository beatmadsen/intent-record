require "test_helper"
require "intent_record/web/app"

class SearchPageTest < WebAcceptanceCase
  def test_search_page_lists_matches_with_links_to_intents
    id = record_intent!(summary: "Retry fetch", body: "with backoff")["intent_id"]
    record_intent!(summary: "Unrelated", body: "nothing")

    get "/search", q: "backoff"

    assert_equal 200, last_response.status
    assert_body_includes %(href="/intents/#{id}")
    refute_body_includes "Unrelated"
  end

  def test_search_with_no_matches_says_so
    get "/search", q: "nothing-here"

    assert_body_includes "No intent"
  end
end
