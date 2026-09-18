require "test_helper"
require "intent_record/web/app"

class HomePageTest < WebAcceptanceCase
  def test_home_shows_lookup_form_and_recent_intents
    record_intent!(summary: "Retry HTTP fetch", commits: [HASH])

    get "/"

    assert_equal 200, last_response.status
    assert_body_includes 'name="q"'
    assert_body_includes "Retry HTTP fetch"
    assert_body_includes HASH[0, 12]
  end

  def test_home_with_no_records_explains_how_to_record_one
    get "/"

    assert_body_includes "intent-record record"
  end
end
