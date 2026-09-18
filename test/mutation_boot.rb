# Boot file for the mutation lane (see .mutineer.yml).
#
# Mutineer loads this once in the parent process and then forks per mutant, so
# every constant it mutates has to exist here. `intent_record` deliberately does
# not require the web layer, because the CLI has no reason to load Sinatra; the
# web acceptance tests require it themselves. Without this file the whole
# lib/intent_record/web tree errored out with "uninitialized constant
# IntentRecord::Web" and the lane still reported a passing score.
require "intent_record"
require "intent_record/web/app"
require "intent_record/web/boot"
