require "kemal"

module Comixone::Api::Routing
  abstract class Base
    getter app : Comixone::Api::Application

    def initialize(@app)
    end

    abstract def register
  end
end
