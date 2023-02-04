module Ameba::AST
  class TypeDecVariable
    getter node : Crystal::TypeDeclaration

    delegate location, to: @node
    delegate end_location, to: @node
    delegate to_s, to: @node

    def initialize(@node)
    end

    def name
      var = @node.var

      case var
      when Crystal::Var
        var.name
      when Crystal::InstanceVar
        var.name
      when Crystal::ClassVar
        var.name
      when Crystal::Global
        var.name
      else
        raise "unsupported type declaration var node"
      end
    end
  end
end
