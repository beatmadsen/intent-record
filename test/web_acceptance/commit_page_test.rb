require "test_helper"
require "intent_record/web/app"

class CommitPageTest < WebAcceptanceCase
  def test_commit_page_lists_intents_with_body_and_stakeholder_links
    jira = { "system" => "jira", "uri" => "https://j/ACME-1", "title" => "Flaky fetch" }
    record_intent!(summary: "Retry fetch", body: "Network was flaky.", author: "claude", commits: [HASH],
                   stakeholder_references: [jira])

    get "/commits/#{HASH}"

    assert_equal 200, last_response.status
    assert_body_includes "Retry fetch"
    assert_body_includes "Network was flaky."
    assert_body_includes "claude"
    assert_body_includes 'href="https://j/ACME-1"'
    assert_body_includes "Flaky fetch"
  end

  def test_commit_page_resolves_short_prefix_and_shows_full_hash
    record_intent!(commits: [HASH])

    get "/commits/#{HASH[0, 7]}"

    assert_equal 200, last_response.status
    assert_body_includes HASH
  end

  def test_unknown_commit_is_a_404_with_explanation
    get "/commits/deadbeef"

    assert_equal 404, last_response.status
    assert_body_includes "deadbeef"
    assert_body_includes "No intent"
  end

  def test_ambiguous_prefix_is_explained
    record_intent!(commits: ["abcdef1111111111111111111111111111111111"])
    record_intent!(commits: ["abcdef2222222222222222222222222222222222"])

    get "/commits/abcdef"

    assert_equal 400, last_response.status
    assert_body_includes "Ambiguous"
  end

  def test_body_is_html_escaped
    record_intent!(body: "<script>alert(1)</script>", commits: [HASH])

    get "/commits/#{HASH}"

    refute_body_includes "<script>alert(1)</script>"
    assert_body_includes "&lt;script&gt;"
  end
end
