require_relative "lib/intent_record/version"

NOT_PACKAGED = /\A(Gemfile|Rakefile|CLAUDE\.md|CONTRIBUTING\.md)\z/
NOT_PACKAGED_PREFIXES = %w[bin/ test/ .].freeze

packaged = lambda do |path|
  next false if path == File.basename(__FILE__)
  next false if path.start_with?(*NOT_PACKAGED_PREFIXES)

  !path.match?(NOT_PACKAGED)
end

packaged_files = lambda do
  IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).select(&packaged)
  end
end

Gem::Specification.new do |spec|
  spec.name = "intent-record"
  spec.version = IntentRecord::VERSION
  spec.authors = ["Erik T. Madsen"]
  spec.email = []

  spec.summary = "Local records storage for the expressed intent behind individual code changes."
  spec.description = "A local, agent-first store that links the written intent behind a code change " \
                     "to its VCS commit and to stakeholder systems such as Jira, Confluence and Linear. " \
                     "JSON in, JSON out on the CLI, plus a small read-oriented web GUI. " \
                     "A Claude Code skill that drives it is at " \
                     "https://github.com/beatmadsen/claude-skills/tree/main/skills/intent-record."
  spec.homepage = "https://github.com/beatmadsen/intent-record"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = packaged_files.call
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 8.0"
  spec.add_dependency "activesupport", "~> 8.0"
  spec.add_dependency "puma", "~> 6.4"
  spec.add_dependency "rackup", "~> 2.1"
  spec.add_dependency "sinatra", "~> 4.0"
  spec.add_dependency "sqlite3", "~> 2.0"
end
