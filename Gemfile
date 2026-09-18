source "https://rubygems.org"

gemspec

gem "concurrent-ruby", "~> 1.3"
gem "minitest", "~> 5.0"
# Mutineer needs Ruby 3.4. The gem supports 3.2, so on an older Ruby the mutation
# lane is missing rather than the whole bundle being unresolvable.
gem "mutineer", "~> 1.0", require: false if RUBY_VERSION >= "3.4"
gem "rack-test", "~> 2.1"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.60", require: false
