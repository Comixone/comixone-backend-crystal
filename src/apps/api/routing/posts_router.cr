require "./base"
require "../handlers/v1/posts/*"

module Comixone::Api::Routing
  class PostsRouter < Base
    def register
      # Get all posts
      get "/v1/posts" do |env|
        Comixone::Api::Handlers::V1::Posts::ListHandler.new(@app).handle(env)
      end

      # Get a specific post
      get "/v1/posts/:id" do |env|
        Comixone::Api::Handlers::V1::Posts::GetHandler.new(@app).handle(env)
      end

      # Create a new post
      post "/v1/posts" do |env|
        Comixone::Api::Handlers::V1::Posts::CreateHandler.new(@app).handle(env)
      end

      # Update a post
      put "/v1/posts/:id" do |env|
        Comixone::Api::Handlers::V1::Posts::UpdateHandler.new(@app).handle(env)
      end

      # Delete a post
      delete "/v1/posts/:id" do |env|
        Comixone::Api::Handlers::V1::Posts::DeleteHandler.new(@app).handle(env)
      end
    end
  end
end
