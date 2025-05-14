require "../../base"
require "../../../../../models/post"

module Comixone::Api::Handlers::V1::Posts
  # Handler for creating a post
  class CreateHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"

      begin
        # Parse the request body
        body = env.request.body.try &.gets_to_end

        if body.nil? || body.empty?
          return error(env, "E_INVALID_REQUEST", "Request body is empty", "CLIENT_ERROR", handler)
        end

        post_data = JSON.parse(body)

        # Create a new post from the request data
        post = Comixone::Models::Post.new(
          title: post_data["title"]?.try(&.as_s) || "Untitled",
          content: post_data["content"]?.try(&.as_s) || ""
        )

        # Set an ID (in a real app, this would come from the database)
        post.id = Random.new.hex(8)

        # Example implementation - in a real app, you would save the post to the database
        # @app.couchdb.create_document(post.to_db_hash)

        success(env, post, handler)
      rescue ex
        error(env, "E_SYSTEM_ERROR", ex.message || "Failed to create post", "SYSTEM_ERROR", handler)
      end
    end
  end
end
