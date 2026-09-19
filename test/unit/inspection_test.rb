require "test_helper"

# What a dry run gathers to show a person afterwards. A write run gathers
# nothing, because it is not an inspection.
class InspectionTest < Minitest::Test
  Inspection = IntentRecord::Backfill::Inspection

  JIRA = [{ "system" => "jira", "uri" => "https://acme.atlassian.net/browse/ACME-42" }].freeze

  def dry
    Inspection.new(true)
  end

  def test_a_missed_subject_is_shown
    seen = dry
    seen.missed("Fix a typo")

    assert_equal ["Fix a typo"], seen.to_h["unmatched"]
  end

  def test_a_missed_subject_counts_as_a_skip
    assert_equal :skipped, dry.missed("Fix a typo")
  end

  # A real history has thousands of unmatched commits and nobody reads
  # thousands of lines.
  def test_the_missed_list_stops_at_the_cap
    seen = dry
    (Inspection::UNMATCHED_SHOWN + 10).times { |i| seen.missed("no key #{i}") }

    assert_equal Inspection::UNMATCHED_SHOWN, seen.to_h["unmatched"].size
  end

  # A commit with no message has no subject to show, and a column of blank
  # lines says nothing about what the pattern missed.
  def test_a_blank_subject_is_counted_but_not_shown
    seen = dry
    seen.missed("")

    assert_empty seen.to_h["unmatched"]
  end

  def test_noted_references_are_reported_as_their_uris
    seen = dry
    seen.noted(JIRA)

    assert_equal ["https://acme.atlassian.net/browse/ACME-42"], seen.to_h["sources"]
  end

  # Two commits naming one ticket would otherwise offer it twice.
  def test_the_same_source_noted_twice_is_reported_once
    seen = dry
    2.times { seen.noted(JIRA) }

    assert_equal 1, seen.to_h["sources"].size
  end

  # The counts of a dry run and a write run look identical, so the result has
  # to say which it was.
  def test_a_dry_run_says_it_was_one
    assert_equal true, dry.to_h["dry_run"]
  end

  def test_a_write_run_reports_nothing_of_its_own
    seen = Inspection.new(false)
    seen.missed("Fix a typo")
    seen.noted(JIRA)

    assert_empty seen.to_h
  end

  def test_a_write_run_still_counts_a_miss_as_a_skip
    assert_equal :skipped, Inspection.new(false).missed("Fix a typo")
  end
end
