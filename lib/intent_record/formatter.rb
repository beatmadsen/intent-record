module IntentRecord
  # Turns models into the JSON shapes the CLI emits. Internal ids never leak.
  #
  # `full` reads four associations per record and does not load them itself, so a
  # caller formatting more than one record hands it a scope through `preloaded`.
  # Loading them here instead would query once per record however the caller
  # asked, which is most of the work in a list of two hundred.
  module Formatter
    PRELOADS = [{ asset_versions: :vcs_system },
                { stakeholder_sources: :stakeholder_system },
                { outgoing_links: :target },
                { incoming_links: :source }].freeze

    module_function

    def preloaded(scope)
      scope.preload(*PRELOADS)
    end

    def summary(record)
      {
        "intent_id" => record.global_id,
        "summary" => record.summary,
        "author" => record.author,
        "created_at" => record.created_at.utc.iso8601
      }
    end

    def full(record)
      summary(record).merge("body" => record.body).merge(external_links(record)).merge(intent_links(record))
    end

    def external_links(record)
      {
        "asset_versions" => record.asset_versions.map { |v| asset_version(v) },
        "stakeholder_references" => record.stakeholder_sources.map { |s| source(s) }
      }
    end

    def intent_links(record)
      {
        "related_intents" => record.outgoing_links.map { |l| summary(l.target) },
        "related_by_intents" => record.incoming_links.map { |l| summary(l.source) }
      }
    end

    def asset_version(version)
      { "vcs" => version.vcs_system.name, "external_id" => version.external_id }
    end

    def source(source)
      { "system" => source.stakeholder_system.name, "uri" => source.uri, "title" => source.title }
    end

    # Steps of `full`. Only `full`, `preloaded`, `asset_version` and `source` are
    # asked for from outside.
    private_class_method :summary, :external_links, :intent_links
  end
end
