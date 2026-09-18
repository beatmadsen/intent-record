module IntentRecord
  # Turns models into the JSON shapes the CLI emits. Internal ids never leak.
  module Formatter
    module_function

    def summary(record)
      {
        "intent_id" => record.global_id,
        "summary" => record.summary,
        "author" => record.author,
        "created_at" => record.created_at.utc.iso8601
      }
    end

    def full(record)
      summary(record).merge("body" => record.body).merge(links(record))
    end

    def links(record)
      {
        "asset_versions" => record.asset_versions.includes(:vcs_system).map { |v| asset_version(v) },
        "stakeholder_references" => record.stakeholder_sources.includes(:stakeholder_system).map { |s| source(s) },
        "related_intents" => record.outgoing_links.includes(:target).map { |l| summary(l.target) },
        "related_by_intents" => record.incoming_links.includes(:source).map { |l| summary(l.source) }
      }
    end

    def asset_version(version)
      { "vcs" => version.vcs_system.name, "external_id" => version.external_id }
    end

    def source(source)
      { "system" => source.stakeholder_system.name, "uri" => source.uri, "title" => source.title }
    end
  end
end
