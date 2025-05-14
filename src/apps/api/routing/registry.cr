require "kemal"
require "./core_router"
require "./posts_router"
require "./users_router"

module Comixone::Api::Routing
  # Main router registry that sets up all application routes
  class Registry
    def self.setup(app)
      # Register core routes
      CoreRouter.new(app).register

      # Register API routes
      PostsRouter.new(app).register
      UsersRouter.new(app).register

      # Add more routers here as needed

      # Global error handler
      Kemal.config.add_error_handler(Exception) do |error, env|
        env.response.content_type = "application/json"
        env.response.status_code = 500

        {
          error:   {code: "E_SYSTEM_ERROR", message: error.message || "Internal Server Error"},
          status:  "SYSTEM_ERROR",
          body:    nil,
          route:   env.request.path,
          handler: "",
        }.to_json
      end
    end
  end
end
