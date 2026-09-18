module IntentRecord
  class CLI
    USAGE = <<~USAGE.freeze
      Usage: intent-record <command> [options]

      Commands:
        record                          Record the intent behind a change (JSON via stdin)
        attach <intent_id>              Link more commits / stakeholder refs / related intents (JSON via stdin)
        show <intent_id>                Full intent record
        lookup <commit> [--vcs name]    Intents recorded against a commit (full hash or unique prefix)
        search <terms...> [--match all] Substring search over summary and body
        by-source <uri> [--contains]    Intents linked to a stakeholder uri (Jira ticket, Confluence page, ...)
        recent [--limit N]              Newest intents first
        systems                         Known vcs and stakeholder system names
        serve [--port N]                Start the local web GUI

      Options:
        --config-dir <dir>              Use the store in this directory instead of ~/.intent-record
        --help, -h                      Show this help
        --version                       Show version

      Input shape for record/attach (all keys optional except summary and body on record):
        {"summary": "...", "body": "...", "author": "...",
         "commits": ["<git hash>"], "asset_versions": [{"vcs": "perforce", "external_id": "123"}],
         "stakeholder_references": [{"system": "jira", "uri": "https://...", "title": "..."}],
         "related_intent_ids": ["<intent_id>"]}
    USAGE
  end
end
