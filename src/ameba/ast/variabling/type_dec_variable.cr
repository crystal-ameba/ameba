module Ameba::AST
  class TypeDecVariable
    getter node : Crystal::TypeDeclaration

    delegate location, end_location, to_s,
      to: @node

    def initialize(@node)
    end

    def name
      case var = @node.var
      when Crystal::Var, Crystal::InstanceVar, Crystal::ClassVar, Crystal::Global
        var.name
      else
        raise "Unsupported var node type: #{var.class}"
      end
    end
  end
end
