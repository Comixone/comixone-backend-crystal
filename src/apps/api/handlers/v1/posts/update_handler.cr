require "../../base"
require "../../../../../models/post"

module Comixone::Api::Handlers::V1::Posts
  # Handler for updating a post
  class UpdateHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"
      id = env.params.url["id"]

      begin
        # Parse the request body
        body = env.request.body.try &.gets_to_end

        if body.nil? || body.empty?
          return error(env, "E_INVALID_REQUEST", "Request body is empty", "CLIENT_ERROR", handler)
        end

        post_data = JSON.parse(body)

        # In a real app, you would first fetch the post from the database
        # post = @app.couchdb.get_document(id)

        # Create an updated post from the request data
        post = Comixone::Models::Post.new(
          title: post_data["title"]?.try(&.as_s) || "Untitled",
          content: post_data["content"]?.try(&.as_s) || ""
        )

        # Set the ID and update timestamp
        post.id = id
        post.update

        # Example implementation - in a real app, you would update the post in the database
        # @app.couchdb.update_document(id, post.to_db_hash)

        success(env, post, handler)
      rescue ex
        error(env, "E_SYSTEM_ERROR", ex.message || "Failed to update post", "SYSTEM_ERROR", handler)
      end
    end
  end
end
