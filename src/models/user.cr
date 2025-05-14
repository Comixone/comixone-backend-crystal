require "./base"
require "crypto/bcrypt/password"

module Comixone::Models
  class User < Base
    property email : String
    property name : String
    property password_hash : String
    property type : String = "user"
    property roles : Array(String) = ["user"]

    def initialize(@email : String, @name : String, password : String)
      super()
      @password_hash = Crypto::Bcrypt::Password.create(password, cost: 10).to_s
    end

    # Create a User from JSON
    def self.from_json_str(json_str : String)
      User.from_json(json_str)
    end

    # Create a User from JSON object
    def self.from_json_object(json_obj : JSON::Any)
      email = json_obj["email"]?.try(&.as_s) || ""
      name = json_obj["name"]?.try(&.as_s) || ""
      password = json_obj["password"]?.try(&.as_s) || ""

      # If we're loading from DB and already have a password hash
      password_hash = json_obj["password_hash"]?.try(&.as_s) || ""

      user = if password_hash.empty?
               User.new(email: email, name: name, password: password)
             else
               User.new(email: email, name: name, password: "").tap do |u|
                 u.password_hash = password_hash
               end
             end

      # Set additional properties
      user.id = json_obj["id"]?.try(&.as_s)

      if roles = json_obj["roles"]?.try(&.as_a?)
        user.roles = roles.map(&.as_s)
      end

      if created_at_str = json_obj["created_at"]?.try(&.as_s)
        user.created_at = Time.parse_iso8601(created_at_str)
      end

      if updated_at_str = json_obj["updated_at"]?.try(&.as_s)
        user.updated_at = Time.parse_iso8601(updated_at_str)
      end

      user
    end

    # Verify a password
    def verify_password(password : String) : Bool
      bcrypt_password = Crypto::Bcrypt::Password.new(@password_hash)
      bcrypt_password.verify(password)
    end

    # Check if user has a specific role
    def has_role?(role : String) : Bool
      @roles.includes?(role)
    end

    # Add a role to the user
    def add_role(role : String)
      @roles << role unless has_role?(role)
      update
    end

    # Remove a role from the user
    def remove_role(role : String)
      @roles.delete(role)
      update
    end

    # Convert to a Hash for database storage
    def to_db_hash
      {
        "_id"           => @id,
        "type"          => @type,
        "email"         => @email,
        "name"          => @name,
        "password_hash" => @password_hash,
        "roles"         => @roles,
        "created_at"    => @created_at.to_s,
        "updated_at"    => @updated_at.to_s,
      }.compact
    end

    # Exclude password_hash from JSON output
    def to_json(json : JSON::Builder)
      json.object do
        json.field "id", @id
        json.field "email", @email
        json.field "name", @name
        json.field "roles", @roles
        json.field "created_at", @created_at
        json.field "updated_at", @updated_at
      end
    end
  end
end
