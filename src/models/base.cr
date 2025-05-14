require "json"
require "time"

module Comixone::Models
  # Base model class for all models
  abstract class Base
    include JSON::Serializable

    property id : String?
    property created_at : Time
    property updated_at : Time

    def initialize
      @created_at = Time.utc
      @updated_at = Time.utc
    end

    # Update the updated_at timestamp
    def update
      @updated_at = Time.utc
    end

    # Convert to a Hash for database storage
    abstract def to_db_hash

    # Static method to create object from JSON
    def self.from_json_object(json_obj : JSON::Any)
      raise "Not implemented"
    end

    # Default JSON serialization
    def to_json(json : JSON::Builder)
      json.object do
        json.field "id", @id
        json.field "created_at", @created_at
        json.field "updated_at", @updated_at
      end
    end
  end
end
