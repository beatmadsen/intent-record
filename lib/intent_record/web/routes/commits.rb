require_relative "../../commands/lookup"

module IntentRecord
  module Web
    module Routes
      module Commits
        def self.registered(app)
          app.get "/commits/:external_id" do
            result = Commands::Lookup.new(external_id: params[:external_id], vcs: params[:vcs]).call
            erb :commit, locals: { version: result["asset_version"], intents: result["intents"] }
          end
        end
      end
    end
  end
end
