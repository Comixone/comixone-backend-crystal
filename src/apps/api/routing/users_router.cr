require "./base"
require "../handlers/v1/users/*"

module Comixone::Api::Routing
  # Router for user-related routes
  class UsersRouter < Base
    def register
      # User login
      post "/v1/users/login" do |env|
        Comixone::Api::Handlers::V1::Users::LoginHandler.new(@app).handle(env)
      end

      # User registration
      post "/v1/users/register" do |env|
        Comixone::Api::Handlers::V1::Users::RegisterHandler.new(@app).handle(env)
      end

      # Get current user profile
      get "/v1/users/profile" do |env|
        Comixone::Api::Handlers::V1::Users::ProfileHandler.new(@app).handle(env)
      end
    end
  end
end
