# Driving `backfill` with a jira pattern, shared by the tests that ask what it
# writes, what a dry run reports and how it chains a ticket's commits.
module BackfillDsl
  TICKET = "https://acme.atlassian.net/browse/ACME-42".freeze
  PREFIX = "https://acme.atlassian.net/browse/".freeze

  RETRY_HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze
  SECOND_HASH = "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e".freeze
  THIRD_HASH = "fedcba9876543210fedcba9876543210fedcba98".freeze
  TYPO_HASH = "0123456789abcdef0123456789abcdef01234567".freeze

  RETRY_SUBJECT = "ACME-42 Retry flaky fetches".freeze
  TIMEOUT_SUBJECT = "ACME-42 Raise the timeout".freeze
  LOGGING_SUBJECT = "ACME-42 Log the retries".freeze

  def backfill_command(**)
    IntentRecord::Commands::Backfill.scanning(system: "jira", pattern: 'ACME-\d+', uri_prefix: PREFIX, **)
  end

  def backfill(commits, **)
    backfill_command(**).call({ "commits" => commits })
  end

  def commit(hash: RETRY_HASH, message: RETRY_SUBJECT, **rest)
    { "commit" => hash, "message" => message }.merge(rest.transform_keys(&:to_s))
  end

  def unmatched_commit(hash: TYPO_HASH, message: "Fix a typo")
    commit(hash: hash, message: message)
  end

  def intent_titled(summary)
    IntentRecord::Models::IntentRecord.find_by!(summary: summary)
  end

  def builds_on(summary)
    intent_titled(summary).outgoing_links.map { |link| link.target.summary }
  end
end
