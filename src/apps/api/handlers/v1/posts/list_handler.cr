require "../../base"
require "../../../../../models/post"

module Comixone::Api::Handlers::V1::Posts
  # Handler for listing posts
  class ListHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"

      begin
        # Example implementation - in a real app, you would get posts from the database
        posts = [
          Comixone::Models::Post.new(title: "First Post", content: "This is the first post").tap { |p| p.id = "1" },
          Comixone::Models::Post.new(title: "Second Post", content: "This is the second post").tap { |p| p.id = "2" },
        ]

        success(env, posts, handler)
      rescue ex
        error(env, "E_SYSTEM_ERROR", ex.message || "Failed to get posts", "SYSTEM_ERROR", handler)
      end
    end
  end
end
