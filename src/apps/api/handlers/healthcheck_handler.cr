require "./base"

module Comixone::Api::Handlers
  class HealthCheckHandler < Base
    def handle(env)
      env.response.content_type = "text/plain"

      if @app.couchdb.healthy? && @app.dragonfly.healthy?
        "ok"
      else
        env.response.status_code = 503
        "service unavailable"
      end
    end
  end
end
