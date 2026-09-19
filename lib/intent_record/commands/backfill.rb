require_relative "record"
require_relative "../backfill/backfilled_intent"
require_relative "../backfill/commit_specs"
require_relative "../backfill/reference_scanner"
require_relative "../models/asset_version"
require_relative "../models/intent_record"
require_relative "../models/stakeholder_source"
require_relative "../stakeholder_normalizer"
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
      # A real history has thousands of unmatched commits and nobody reads
      # thousands of lines. Enough to recognise a convention, not enough to
      # bury the counts.
      UNMATCHED_SHOWN = 20

      def initialize(system:, pattern:, uri_prefix: nil, dry_run: false)
        @scanner = IntentRecord::Backfill::ReferenceScanner.new(system: system, pattern: pattern,
                                                                uri_prefix: uri_prefix)
        @dry_run = dry_run
        @unmatched = []
        @sources = []
      end

      def call(input)
        specs = IntentRecord::Backfill::CommitSpecs.from(input)
        report(specs.map { |spec| process(spec) })
      end

      private

      def process(spec)
        references = @scanner.call(searchable(spec))
        return unmatched(spec) if references.empty?
        return :skipped if already_recorded?(spec[:commit])

        noted(references)
        @dry_run ? :created : write!(spec, references)
      rescue Error => e
        { commit: spec[:commit], error: e.message }
      end

      # The pattern is never right the first time, and seeing which subjects
      # matched nothing is how a person finds the second convention their team
      # used. Only a dry run reports them: a write run is not an inspection.
      def unmatched(spec)
        @unmatched << subject(spec) if @dry_run && @unmatched.size < UNMATCHED_SHOWN
        :skipped
      end

      def noted(references)
        @sources.concat(references.map { |r| r["uri"] }) if @dry_run
      end

      def subject(spec)
        spec[:message].strip.lines.first.to_s.strip
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
        intent.to_h.merge("commits" => [spec[:commit]],
                          "stakeholder_references" => references,
                          "related_intent_ids" => predecessors(references))
      end

      # Successive commits for one ticket are almost always a chain, and the
      # link is what makes `show` on any one of them tell the story rather than
      # present an isolated record. Asked of the store rather than remembered
      # within the run, so a second run continues the chain the first one left.
      #
      # The most recent one only: linking to every earlier commit for the ticket
      # would say each builds on all of them, which is a claim the history does
      # not support.
      def predecessors(references)
        references.filter_map { |ref| latest_intent_for(ref) }.uniq
      end

      def latest_intent_for(reference)
        Models::IntentRecord.joins(:stakeholder_sources)
                            .where(stakeholder_sources: { id: source_id(reference) })
                            .order(created_at: :desc, id: :desc).first&.global_id
      end

      def source_id(reference)
        Models::StakeholderSource.joins(:stakeholder_system)
                                 .find_by(stakeholder_systems: {
                                            name: StakeholderNormalizer.system_name(reference["system"])
                                          },
                                          uri: StakeholderNormalizer.uri(reference["uri"]))&.id
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
        counts(outcomes).merge(@dry_run ? inspection : {})
      end

      def counts(outcomes)
        failures = outcomes.grep(Hash)
        { "created" => outcomes.count(:created),
          "skipped" => outcomes.count(:skipped),
          "failed" => failures.size,
          "failures" => failures.map { |f| { "commit" => f[:commit], "error" => f[:error] } } }
      end

      # What a dry run is for: the sources it would create, so they can be
      # eyeballed, and the subjects that matched nothing, so the pattern that
      # missed them can be written.
      def inspection
        { "dry_run" => true, "sources" => @sources.uniq, "unmatched" => @unmatched }
      end
    end
  end
end
