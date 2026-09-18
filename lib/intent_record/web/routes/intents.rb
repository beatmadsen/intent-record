require_relative "../../commands/show"

module IntentRecord
  module Web
    module Routes
      module Intents
        def self.registered(app)
          app.get "/intents/:id" do
            erb :intent, locals: { intent: Commands::Show.new(intent_id: params[:id]).call }
          end
        end
      end
    end
  end
end
