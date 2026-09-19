require_relative "record"
require_relative "../backfill/backfilled_intent"
require_relative "../backfill/commit_specs"
require_relative "../backfill/reference_scanner"
require_relative "../models/asset_version"
require_relative "../asset_version_normalizer"

module IntentRecord
  module Commands
    # Recovers intent records from a history of commit messages.
    #
    # One record per commit that names a reference, because `lookup <hash>` is
    # meaningless if a record's summary describes forty other commits. A ticket
    # spanning commits is what `by-source` already assembles from these.
    #
    # Each commit is its own transaction, so one malformed hash in a history of
    # thousands costs that commit rather than the run. A commit that already has
    # an intent is passed over, which is what makes a second run cheap: finding
    # the convention you missed is the normal way to use this.
    class Backfill
      def initialize(system:, pattern:, uri_prefix: nil, dry_run: false)
        @scanner = IntentRecord::Backfill::ReferenceScanner.new(system: system, pattern: pattern,
                                                                uri_prefix: uri_prefix)
        @dry_run = dry_run
      end

      def call(input)
        specs = IntentRecord::Backfill::CommitSpecs.from(input)
        report(specs.map { |spec| process(spec) })
      end

      private

      def process(spec)
        references = @scanner.call(searchable(spec))
        return :skipped if references.empty? || already_recorded?(spec[:commit])
        return :created if @dry_run

        write!(spec, references)
      rescue Error => e
        { commit: spec[:commit], error: e.message }
      end

      # The key is as often in the branch name as in the message, and a team that
      # puts it there never puts it in both.
      def searchable(spec)
        [spec[:message], spec[:ref]].compact.join("\n")
      end

      def write!(spec, references)
        ActiveRecord::Base.transaction { Commands::Record.new.call(payload(spec, references)) }
        :created
      end

      def payload(spec, references)
        intent = IntentRecord::Backfill::BackfilledIntent.new(message: spec[:message], author: spec[:author])
        intent.to_h.merge("commits" => [spec[:commit]], "stakeholder_references" => references)
      end

      # Asked of the store rather than remembered, so a commit recorded by an
      # earlier run or by hand is passed over just the same.
      def already_recorded?(commit)
        version = Models::AssetVersion.joins(:vcs_system)
                                      .find_by(vcs_systems: { name: "git" }, external_id: lookup_id(commit))
        version&.intent_records&.any? || false
      end

      # A hash that is not a hash cannot match anything stored, and judging its
      # shape here would refuse it before the per-commit rescue can report it.
      def lookup_id(commit)
        AssetVersionNormalizer.lookup_id("git", commit)
      end

      def report(outcomes)
        failures = outcomes.grep(Hash)
        { "created" => outcomes.count(:created),
          "skipped" => outcomes.count(:skipped),
          "failed" => failures.size,
          "failures" => failures.map { |f| { "commit" => f[:commit], "error" => f[:error] } } }
      end
    end
  end
end
