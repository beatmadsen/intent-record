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
        blame [--format name]           Intents for the commits a blame output names (JSON via stdin)
        backfill [options]              Recover intents from commit messages (JSON via stdin, see below)
        serve [--port N]                Start the local web GUI

      Options:
        --config-dir <dir>              Use the store in this directory instead of ~/.intent-record
        --help, -h                      Show this help
        --version                       Show version

      Options for backfill:
        --system <name>                 Stakeholder system the found references belong to (required)
        --pattern <regex>               What a reference looks like in a message (required).
                                        A capture group narrows what is appended to the prefix
        --uri-prefix <url>              Prefix + key = source uri. Without it the whole match is the uri
        --order <which-first>           newest-first (default, as git log prints) or oldest-first
        --dry-run                       Report what it would write, write nothing

      Input shape for blame (vcs defaults to git):
        {"vcs": "git", "lines": [{"line": 40, "external_id": "<hash>"}]}
        With --format git-porcelain, `git blame --porcelain` output goes in as-is.

      Input shape for backfill:
        {"commits": [{"commit": "<hash>", "message": "<commit message>",
                      "author": "...", "ref": "<branch name>"}]}

      Input shape for record/attach (all keys optional except summary and body on record):
        {"summary": "...", "body": "...", "author": "...",
         "commits": ["<git hash>"], "asset_versions": [{"vcs": "perforce", "external_id": "123"}],
         "stakeholder_references": [{"system": "jira", "uri": "https://...", "title": "..."}],
         "related_intent_ids": ["<intent_id>"]}
    USAGE
  end
end
