require "../../base"
require "../../../../../models/post"

module Comixone::Api::Handlers::V1::Posts
  # Handler for getting a specific post
  class GetHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"
      id = env.params.url["id"]

      begin
        # Example implementation - in a real app, you would get the post from the database
        post = Comixone::Models::Post.new(
          title: "Sample Post",
          content: "This is a sample post content"
        ).tap do |p|
          p.id = id
        end

        success(env, post, handler)
      rescue ex
        error(env, "E_SYSTEM_ERROR", ex.message || "Failed to get post", "SYSTEM_ERROR", handler)
      end
    end
  end
end
