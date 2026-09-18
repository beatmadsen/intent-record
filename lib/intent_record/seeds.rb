require_relative "models/vcs_system"
require_relative "models/stakeholder_system"

module IntentRecord
  # Well-known systems seeded on every connect so the store works out of the box.
  # Names are lowercase, hyphenated; user-supplied names are normalised the same way.
  module Seeds
    VCS_SYSTEMS = %w[
      git mercurial subversion perforce fossil bazaar cvs darcs pijul sapling plastic-scm
    ].freeze

    STAKEHOLDER_SYSTEMS = %w[
      jira confluence linear
      github-issues github-pull-requests github-discussions github-projects
      gitlab-issues gitlab-merge-requests gitlab-epics
      bitbucket azure-devops azure-boards
      trello asana notion monday clickup basecamp shortcut youtrack pivotal-tracker
      slack microsoft-teams discord email
      google-docs google-sheets sharepoint dropbox-paper coda
      figma miro lucidchart
      servicenow zendesk intercom freshdesk
      productboard aha airfocus
      doors polarion jama codebeamer
      adr rfc wiki web
    ].freeze

    def self.apply!
      seed!(Models::VcsSystem, VCS_SYSTEMS)
      seed!(Models::StakeholderSystem, STAKEHOLDER_SYSTEMS)
    end

    def self.seed!(model, names)
      existing = model.where(name: names).pluck(:name)
      now = Time.now.utc
      (names - existing).each { |name| model.create!(name: name, created_at: now) }
    end
  end
end
