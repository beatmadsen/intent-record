require_relative "record"
require_relative "../backfill/backfilled_intent"
require_relative "../backfill/commit_specs"
require_relative "../backfill/inspection"
require_relative "../backfill/predecessor_finder"
require_relative "../backfill/reference_scanner"
require_relative "../linkers/stakeholder_linker"
require_relative "../stakeholder_normalizer"
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
      # `git log` prints newest first, which is what a person pipes in without
      # thinking about it, so that is the default. The chain is written oldest
      # to newest either way; this only says which end of the list is which.
      ORDERS = %w[newest-first oldest-first].freeze
      DEFAULT_ORDER = "newest-first".freeze

      def self.scanning(system:, pattern:, uri_prefix: nil, **)
        new(scanner: IntentRecord::Backfill::ReferenceScanner.new(system: system, pattern: pattern,
                                                                  uri_prefix: uri_prefix),
            **)
      end

      def initialize(scanner:, dry_run: false, order: DEFAULT_ORDER)
        @scanner = scanner
        @dry_run = dry_run
        @order = validated_order(order)
      end

      def call(input)
        specs = chronological(IntentRecord::Backfill::CommitSpecs.from(input))
        seen = IntentRecord::Backfill::Inspection.new(@dry_run)
        report(specs.map { |spec| process(spec, seen) }, seen)
      end

      private

      def validated_order(order)
        value = order.to_s.strip.downcase
        return value if ORDERS.include?(value)

        raise ValidationError, "--order must be one of #{ORDERS.join(", ")}, got #{order.inspect}"
      end

      # Each record links to the one before it, so the commits are written in
      # the order they were made whichever end of the history the caller gave.
      def chronological(specs)
        @order == DEFAULT_ORDER ? specs.reverse : specs
      end

      # A commit already recorded keeps its record and gains whatever this pass
      # found, because a second pass exists to link the convention the first
      # pattern did not match. Skipping the commit whole would silently drop
      # every reference in it.
      def process(spec, seen)
        references = @scanner.call(searchable(spec))
        return seen.missed(subject(spec)) if references.empty?

        write(spec, references, seen)
      rescue Error => e
        { commit: spec[:commit], error: e.message }
      end

      # Nothing this pass found is new, which is what a repeated pass looks
      # like: neither created nor linked, and its sources are not offered as
      # ones a dry run would add.
      def write(spec, references, seen)
        existing = recorded_intents(spec[:commit])
        return :skipped if nothing_new?(existing, references)

        seen.noted(references)
        existing.empty? ? create(spec, references) : attach(existing, references)
      end

      def nothing_new?(existing, references)
        existing.any? && already_linked?(existing, references)
      end

      def attach(existing, references)
        return :linked if @dry_run

        ActiveRecord::Base.transaction do
          existing.each { |record| Linkers::StakeholderLinker.call(record, "stakeholder_references" => references) }
        end
        :linked
      end

      def already_linked?(existing, references)
        wanted = references.map { |r| StakeholderNormalizer.uri(r["uri"]) }
        existing.all? { |record| (wanted - record.stakeholder_sources.map(&:uri)).empty? }
      end

      def create(spec, references)
        @dry_run ? :created : write!(spec, references)
      end

      def subject(spec)
        spec[:message].strip.lines.first.to_s.strip
      end

      # The key is as often in the branch name as in the message, and a team
      # that puts it there never puts it in both.
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
                          "related_intent_ids" => IntentRecord::Backfill::PredecessorFinder.for(references))
      end

      # Asked of the store rather than remembered, so a commit recorded by an
      # earlier run or by hand is treated the same.
      def recorded_intents(commit)
        version = Models::AssetVersion.joins(:vcs_system)
                                      .find_by(vcs_systems: { name: "git" }, external_id: lookup_id(commit))
        version ? version.intent_records.to_a : []
      end

      # A hash that is not a hash cannot match anything stored, and judging its
      # shape here would refuse it before the per-commit rescue can report it.
      def lookup_id(commit)
        AssetVersionNormalizer.lookup_id("git", commit)
      end

      def report(outcomes, seen)
        counts(outcomes).merge(seen.to_h)
      end

      def counts(outcomes)
        failures = outcomes.grep(Hash)
        { "created" => outcomes.count(:created),
          "linked" => outcomes.count(:linked),
          "skipped" => outcomes.count(:skipped),
          "failed" => failures.size,
          "failures" => failures.map { |f| { "commit" => f[:commit], "error" => f[:error] } } }
      end
    end
  end
end
