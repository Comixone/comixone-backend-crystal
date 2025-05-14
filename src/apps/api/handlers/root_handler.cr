require "./base"

module Comixone::Api::Handlers
  class RootHandler < Base
    def handle(env)
      env.response.content_type = "text/plain"
      "Hello from Comixone API!"
    end
  end
end
