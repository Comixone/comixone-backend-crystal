#!/usr/bin/env crystal

require "../src/config"
require "../src/lib/couchdb"
require "../src/models/index"

# Setup script to initialize the CouchDB database
# This creates the database and sets up initial views

module Comixone::Setup
  def self.run
    puts "Initializing CouchDB database..."

    # Load the configuration
    config = Comixone::Config.load
    couchdb = Lib::CouchDB.new(config.couchdb)

    puts "Connected to CouchDB at #{config.couchdb.url}"

    # Set up design documents for views
    setup_design_docs(couchdb)

    # Set up initial data if database is empty
    setup_initial_data(couchdb)

    puts "Database setup complete!"
  end

  def self.setup_design_docs(couchdb)
    # Posts view
    posts_design = {
      "_id"   => "_design/posts",
      "views" => {
        "by_date" => {
          "map" => "function(doc) { if (doc.type === 'post') { emit(doc.created_at, doc); } }",
        },
        "by_title" => {
          "map" => "function(doc) { if (doc.type === 'post') { emit(doc.title, doc); } }",
        },
      },
    }

    # Users view
    users_design = {
      "_id"   => "_design/users",
      "views" => {
        "by_email" => {
          "map" => "function(doc) { if (doc.type === 'user') { emit(doc.email, doc); } }",
        },
        "by_role" => {
          "map" => "function(doc) { if (doc.type === 'user') { doc.roles.forEach(function(role) { emit(role, doc); }); } }",
        },
      },
    }

    begin
      couchdb.create_document(posts_design)
      puts "Created posts design document"
    rescue ex
      puts "Posts design document already exists or error: #{ex.message}"
    end

    begin
      couchdb.create_document(users_design)
      puts "Created users design document"
    rescue ex
      puts "Users design document already exists or error: #{ex.message}"
    end
  end

  def self.setup_initial_data(couchdb)
    # Check if we need to create an admin user
    begin
      # Try to find admin users
      admins_query = couchdb.query("_design/users/_view/by_role?key=\"admin\"&limit=1")
      admin_count = admins_query["rows"].as_a.size

      if admin_count == 0
        # Create an admin user
        password = "comixone"
        admin_user = Models::User.new(
          email: "anar.k.jafarov@gmail.com",
          name: "Anar Jafarov",
          password: password
        )
        admin_user.id = "num8er"
        admin_user.add_role("admin")

        couchdb.create_document(admin_user.to_db_hash)
        puts "Created admin user (email: #{admin_user.email}, password: #{password})"
      end
    rescue ex
      puts "Error checking/creating admin user: #{ex.message}"
    end

    # Create some sample posts if none exist
    begin
      # Check existing posts
      posts_query = couchdb.query("_design/posts/_view/by_date?limit=1")
      post_count = posts_query["rows"].as_a.size

      if post_count == 0
        # Create sample posts
        sample_posts = [
          Models::Post.new(
            title: "Welcome to Comixone",
            content: "This is a sample post created when setting up the database."
          ),
          Models::Post.new(
            title: "Getting Started with Comixone",
            content: "To get started, you can log in with the default admin account."
          ),
        ]

        sample_posts.each_with_index do |post, index|
          post.id = "sample-post-#{index + 1}"
          couchdb.create_document(post.to_db_hash)
        end

        puts "Created #{sample_posts.size} sample posts"
      end
    rescue ex
      puts "Error checking/creating sample posts: #{ex.message}"
    end
  end
end

# Run the setup
Comixone::Setup.run
