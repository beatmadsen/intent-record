require_relative "../blame/spans"
require_relative "../blame/porcelain"
require_relative "../asset_version_normalizer"
require_relative "../formatter"
require_relative "../models/asset_version"

module IntentRecord
  module Commands
    # Answers "why is this line here" for a range of lines.
    #
    # Blame output goes in on stdin rather than the tool shelling out to git, so
    # the same command answers for Perforce or Mercurial and the store keeps
    # knowing nothing about which repository a commit belongs to.
    class Blame
      DEFAULT_VCS = "git".freeze

      # Git's all-zero object id, which blame gives a line that is in the working
      # copy and not in the history. It is not a commit, so a reader is told the
      # line is not committed rather than that nothing was recorded against it,
      # and the store is not asked about it at all: the id is a valid shape, so
      # a record can sit under it, and one did, but a line with no history cannot
      # have had anything recorded against it.
      # Forty zeros, or sixty-four in a repository using the sha256 object format.
      UNCOMMITTED = /\A(?:0{40}|0{64})\z/

      def call(input)
        vcs = AssetVersionNormalizer.vcs_name(input["vcs"] || DEFAULT_VCS)
        # Full path: inside Commands::Blame the bare name finds this class.
        spans = IntentRecord::Blame::Spans.new(input["lines"]).call
        { "spans" => answers(spans, vcs) }
      end

      private

      def answers(spans, vcs)
        known = versions(spans.reject { |span| uncommitted?(span, vcs) }, vcs)
        spans.map { |span| answer(span, vcs, known[AssetVersionNormalizer.lookup_id(vcs, span.external_id)]) }
      end

      # Every span is answered, including one whose change the store has never
      # heard of. Leaving it out would read as "this line has no history", which
      # is the opposite of what an empty list of intents says.
      def answer(span, vcs, version)
        answered = {
          "from" => span.from,
          "to" => span.to,
          "asset_version" => { "vcs" => vcs, "external_id" => span.external_id },
          "intents" => intents(version)
        }
        uncommitted?(span, vcs) ? answered.merge("uncommitted" => true) : answered
      end

      def uncommitted?(span, vcs)
        vcs == DEFAULT_VCS && UNCOMMITTED.match?(span.external_id)
      end

      def intents(version)
        return [] if version.nil?

        version.intent_records.map { |record| Formatter.full(record) }
      end

      # Read once for the whole payload rather than per span. A blamed range is a
      # handful of changes however many lines it covers, and asking per span
      # would make the query count grow with the size of the range.
      def versions(spans, vcs)
        ids = spans.map { |span| AssetVersionNormalizer.lookup_id(vcs, span.external_id) }.uniq
        scope = Models::AssetVersion.joins(:vcs_system)
                                    .where(vcs_systems: { name: vcs }, external_id: ids)
                                    .preload(intent_records: Formatter::PRELOADS)
        scope.index_by(&:external_id)
      end
    end
  end
end
