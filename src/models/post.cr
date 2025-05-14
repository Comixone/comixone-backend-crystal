require "./base"
require "json"
require "time"

module Comixone::Models
  class Post < Base
    property title : String
    property content : String
    property type : String = "post"
    property author_id : String?
    property tags : Array(String) = [] of String
    property published : Bool = false
    property published_at : Time?
    property view_count : Int32 = 0
    property likes : Int32 = 0

    def initialize(@title : String, @content : String)
      super()
    end

    # Create a Post from JSON string
    def self.from_json_str(json_str : String)
      from_json(json_str)
    end

    # Create a Post from JSON object
    def self.from_json_object(json_obj : JSON::Any)
      post = new(
        title: json_obj["title"]?.try(&.as_s) || "Untitled",
        content: json_obj["content"]?.try(&.as_s) || ""
      )

      # Set basic fields
      post.id = json_obj["id"]?.try(&.as_s) || json_obj["_id"]?.try(&.as_s)
      post.type = json_obj["type"]?.try(&.as_s) || "post"
      post.author_id = json_obj["author_id"]?.try(&.as_s)
      post.published = json_obj["published"]?.try(&.as_bool) || false
      post.view_count = json_obj["view_count"]?.try(&.as_i) || 0
      post.likes = json_obj["likes"]?.try(&.as_i) || 0

      # Set tags if present
      if tags = json_obj["tags"]?.try(&.as_a)
        post.tags = tags.map(&.as_s)
      end

      # Parse dates
      if created_at_str = json_obj["created_at"]?.try(&.as_s)
        begin
          post.created_at = Time.parse_iso8601(created_at_str)
        rescue
          # If the format is not ISO8601, try a more flexible approach
          post.created_at = Time.parse(created_at_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
        end
      end

      if updated_at_str = json_obj["updated_at"]?.try(&.as_s)
        begin
          post.updated_at = Time.parse_iso8601(updated_at_str)
        rescue
          # If the format is not ISO8601, try a more flexible approach
          post.updated_at = Time.parse(updated_at_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
        end
      end

      if published_at_str = json_obj["published_at"]?.try(&.as_s)
        begin
          post.published_at = Time.parse_iso8601(published_at_str)
        rescue
          # If the format is not ISO8601, try a more flexible approach
          post.published_at = Time.parse(published_at_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
        end
      end

      post
    end

    # Publish the post
    def publish
      @published = true
      @published_at = Time.utc
      update
    end

    # Unpublish the post
    def unpublish
      @published = false
      @published_at = nil
      update
    end

    # Increment view count
    def increment_views
      @view_count += 1
      update
    end

    # Add a like
    def add_like
      @likes += 1
      update
    end

    # Add a tag
    def add_tag(tag : String)
      unless @tags.includes?(tag)
        @tags << tag
        update
      end
    end

    # Remove a tag
    def remove_tag(tag : String)
      if @tags.includes?(tag)
        @tags.delete(tag)
        update
      end
    end

    # Convert to a Hash for database storage
    def to_db_hash
      hash = {
        "type"       => @type,
        "title"      => @title,
        "content"    => @content,
        "created_at" => @created_at.to_s,
        "updated_at" => @updated_at.to_s,
        "published"  => @published,
        "tags"       => @tags,
        "view_count" => @view_count,
        "likes"      => @likes,
      } of String => String | Int32 | Bool | Array(String) | Time

      # Add optional fields if present
      hash["_id"] = @id.not_nil! if @id
      hash["author_id"] = @author_id.not_nil! if @author_id
      hash["published_at"] = @published_at.not_nil!.to_s if @published_at

      hash
    end

    # Custom JSON serialization
    def to_json(json : JSON::Builder)
      json.object do
        json.field "id", @id
        json.field "type", @type
        json.field "title", @title
        json.field "content", @content
        json.field "created_at", @created_at
        json.field "updated_at", @updated_at
        json.field "published", @published
        json.field "tags", @tags
        json.field "view_count", @view_count
        json.field "likes", @likes

        # Add optional fields if present
        json.field "author_id", @author_id if @author_id
        json.field "published_at", @published_at if @published_at
      end
    end

    # Get a summary of the post (first few words)
    def summary(word_count = 25)
      words = @content.split(/\s+/)
      if words.size <= word_count
        @content
      else
        words[0...word_count].join(" ") + "..."
      end
    end

    # Check if the post is recently published (within the last 7 days)
    def recently_published?
      return false unless @published && @published_at

      (Time.utc - @published_at.not_nil!) < 7.days
    end

    # Check if the post is trending (high view count relative to age)
    def trending?
      age_in_days = (Time.utc - @created_at).total_days
      return false if age_in_days <= 0

      # Simple trending formula: views per day > 10
      @view_count / age_in_days > 10
    end
  end
end
