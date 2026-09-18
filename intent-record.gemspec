require_relative "lib/intent_record/version"

Gem::Specification.new do |spec|
  spec.name = "intent-record"
  spec.version = IntentRecord::VERSION
  spec.authors = ["Erik T. Madsen"]
  spec.email = []

  spec.summary = "Local records storage for the expressed intent behind individual code changes."
  spec.description = "A local, agent-first store that links the written intent behind a code change " \
                     "to its VCS commit and to stakeholder systems such as Jira, Confluence and Linear. " \
                     "JSON in, JSON out on the CLI, plus a small read-oriented web GUI."
  spec.homepage = "https://github.com/beatmadsen/intent-record"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ .]) ||
        f.match?(/\A(Gemfile|Rakefile|CLAUDE\.md)\z/)
    end
  end
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
