require "./base"
require "../handlers/root_handler"
require "../handlers/healthcheck_handler"
require "../handlers/manifest_handler"

module Comixone::Api::Routing
  # Router for core application routes
  class CoreRouter < Base
    def register
      # Root route
      get "/" do |env|
        Comixone::Api::Handlers::RootHandler.new(@app).handle(env)
      end

      # Health check route
      get "/healthz" do |env|
        Comixone::Api::Handlers::HealthCheckHandler.new(@app).handle(env)
      end

      # Manifest route
      get "/manifest" do |env|
        Comixone::Api::Handlers::ManifestHandler.new(@app).handle(env)
      end

      # 404 handler
      error 404 do |env|
        env.response.content_type = "application/json"

        {
          error:   {code: "E_NOT_FOUND", message: "Resource not found"},
          status:  "CLIENT_ERROR",
          body:    nil,
          route:   env.request.path,
          handler: "",
        }.to_json
      end
    end
  end
end
