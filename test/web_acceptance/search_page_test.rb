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

# The search page shows a card per hit and the card shows the body, which is
# fine for the one record a commit page shows and unreadable for the two hundred
# a search can return. A result carries the fragment the terms landed in, and
# that is what a list of them should show.
class SearchPageSnippetTest < WebAcceptanceCase
  BURIED = "The reason we retried the fetch.".freeze

  # Named so the test can say the far end of the body never reached the page.
  # The fragment is a window around the match and carries context on both sides,
  # so the prose immediately after it is expected to show.
  FAR_END = "This last sentence sits far past the fragment.".freeze

  def long_body
    "#{"Prose that is not why anyone searched. " * 40}#{BURIED}#{" Trailing prose." * 40} #{FAR_END}"
  end

  def test_a_result_shows_the_fragment_the_terms_landed_in_rather_than_the_whole_body
    record_intent!(summary: "Rename the config loader", body: long_body)

    get "/search", q: "retry"

    assert_body_includes BURIED
    refute_body_includes FAR_END
  end

  # The same card is shown wherever one record is read on its own, and there the
  # body is the thing the reader came for.
  def test_a_page_showing_one_record_still_shows_its_whole_body
    id = record_intent!(summary: "Rename the config loader", body: long_body)["intent_id"]

    get "/intents/#{id}"

    assert_body_includes FAR_END
  end
end
