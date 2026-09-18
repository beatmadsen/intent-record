require_relative "../../commands/recent"
require_relative "../query_router"

module IntentRecord
  module Web
    module Routes
      module Home
        def self.registered(app)
          app.get "/" do
            recent = Commands::Recent.new(limit: 20).call
            erb :home, locals: { recent: recent["intents"] }
          end

          app.get "/go" do
            redirect QueryRouter.path_for(params[:q])
          end
        end
      end
    end
  end
end
