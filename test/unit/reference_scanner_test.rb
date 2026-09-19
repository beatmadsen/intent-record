require "test_helper"

# What a commit message asks for, before anything is written. The scanner never
# reaches the database, so the matching rules can be exercised without one.
class ReferenceScannerTest < Minitest::Test
  Scanner = IntentRecord::Backfill::ReferenceScanner

  def scanner(pattern: 'ACME-\d+', uri_prefix: "https://acme.atlassian.net/browse/", system: "jira")
    Scanner.new(system: system, pattern: pattern, uri_prefix: uri_prefix)
  end

  def test_whole_match_is_appended_to_the_prefix_when_the_pattern_has_no_group
    found = scanner.call("ACME-42 Retry flaky fetches")

    assert_equal [{ "system" => "jira", "uri" => "https://acme.atlassian.net/browse/ACME-42",
                    "title" => "ACME-42" }], found
  end

  # Linear and Jira keys look alike, so the prefix carries the project and the
  # group carries only the number.
  def test_capture_group_is_what_gets_appended_when_the_pattern_has_one
    found = scanner(pattern: 'ENG-(\\d+)', uri_prefix: "https://linear.app/acme/issue/ENG-", system: "linear")
            .call("ENG-7 Rework the queue")

    assert_equal "https://linear.app/acme/issue/ENG-7", found.sole["uri"]
  end

  # The group narrows the uri, not the name. A source titled "7" tells a reader
  # nothing and makes `search ENG-7` miss it.
  def test_title_is_the_matched_text_even_where_a_group_narrowed_the_uri
    found = scanner(pattern: 'ENG-(\\d+)', uri_prefix: "https://linear.app/acme/issue/ENG-", system: "linear")
            .call("ENG-7 Rework the queue")

    assert_equal "ENG-7", found.sole["title"]
  end

  def test_the_whole_match_is_the_uri_when_no_prefix_is_given
    found = scanner(pattern: 'https://acme\\.atlassian\\.net/wiki/\\S+', uri_prefix: nil, system: "confluence")
            .call("Per https://acme.atlassian.net/wiki/spaces/ENG/pages/17 we split the reader.")

    assert_equal "https://acme.atlassian.net/wiki/spaces/ENG/pages/17", found.sole["uri"]
  end

  # A merge commit names the same ticket in its subject and in the branch it
  # merged. One source, not two.
  def test_the_same_key_twice_in_one_message_is_one_reference
    found = scanner.call("Merge ACME-42 into main\n\nACME-42 Retry flaky fetches")

    assert_equal 1, found.size
  end

  def test_several_keys_in_one_message_each_become_a_reference
    found = scanner.call("ACME-42 and ACME-43 both needed the same fix")

    assert_equal(["https://acme.atlassian.net/browse/ACME-42",
                  "https://acme.atlassian.net/browse/ACME-43"], found.map { |r| r["uri"] })
  end

  def test_a_message_naming_nothing_yields_no_references
    assert_empty scanner.call("Fix a typo in the README")
  end

  # Each match keeps its own text. Reading the match state per iteration rather
  # than once is what makes that true, so a message with several distinct keys
  # must title each one after itself, and the group must not bleed between them.
  def test_each_match_keeps_its_own_matched_text
    found = scanner(pattern: 'ACME-(\\d+)').call("ACME-42 and ACME-43")

    assert_equal(%w[ACME-42 ACME-43], found.map { |r| r["title"] })
    assert_equal(%w[https://acme.atlassian.net/browse/42 https://acme.atlassian.net/browse/43],
                 found.map { |r| r["uri"] })
  end

  # Two matches that narrow to the same key are the same ticket named twice, so
  # they are one source and the first text it was found under names it.
  def test_matches_narrowing_to_one_key_collapse_to_the_first_title
    found = scanner(pattern: "(?:ACME|acme)-(42)").call("ACME-42 then acme-42")

    assert_equal "ACME-42", found.sole["title"]
  end

  # The pattern is the person's own, and a hang would give them no output and no
  # way to tell what went wrong. Ruby's engine memoises its way out of every
  # catastrophic pattern this suite could find, so what is pinned here is that
  # the budget is set on the compiled pattern: it is the part that would regress
  # silently, and it is the whole of the guard on a Ruby whose engine gives up.
  def test_the_compiled_pattern_carries_a_match_timeout
    compiled = scanner.send(:instance_variable_get, :@pattern)

    assert_equal Scanner::MATCH_TIMEOUT_SECONDS, compiled.timeout
  end

  # And that a timeout, however it arises, is reported as a pattern problem
  # rather than escaping as an engine error nobody can act on. No pattern this
  # suite can write makes this engine time out, so the message is made to raise
  # it instead of the pattern.
  def test_a_match_timeout_is_reported_against_the_pattern
    timing_out = Object.new
    def timing_out.to_s = raise(Regexp::TimeoutError)

    error = assert_raises(IntentRecord::ValidationError) { scanner.call(timing_out) }

    assert_match(/pattern/i, error.message)
  end

  def test_a_pattern_that_is_not_a_regex_is_reported_as_such
    error = assert_raises(IntentRecord::ValidationError) { scanner(pattern: "ACME-[") }

    assert_match(/pattern/i, error.message)
  end
end
