module Ameba::AST
  class InstanceVariable
    getter node : Crystal::InstanceVar

    delegate location, end_location, name, to_s,
      to: @node

    def initialize(@node)
    end
  end
end
