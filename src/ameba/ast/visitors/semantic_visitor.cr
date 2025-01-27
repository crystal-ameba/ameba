module Ameba::AST
  # A simple visitor that iterates over a single files parser-only tree, resolving the
  # namespaces to their corresponding namespace types.
  #
  # TODO: expand this to also include information about the current scope
  class SemanticVisitor < BaseVisitor
    getter context : SemanticContext
    getter current_type : Crystal::ModuleType

    def initialize(@rule, @source, @context : SemanticContext)
      @current_type = @context.program

      super(@rule, @source)
    end

    def visit(node : Crystal::ClassDef | Crystal::ModuleDef | Crystal::LibDef)
      @rule.test(@source, node, current_type)

      # `Lint/NoSemanticInformation` should catch this edge case
      type = current_type.lookup_type?(node.name).try(&.as?(Crystal::ModuleType))

      # Don't visit bodies of types we don't have any semantic information for.
      # This is reported by `Lint/NoSemanticInformation`
      return false unless type

      pushing_type(type) do
        node.body.accept(self)
      end

      false
    end

    def visit(node : Crystal::EnumDef)
      @rule.test(@source, node, current_type)

      # `Lint/NoSemanticInformation` should catch this edge case
      type = current_type.lookup_type?(node.name).try(&.as?(Crystal::ModuleType))

      # Don't visit bodies of types we don't have any semantic information for.
      # This is reported by `Lint/NoSemanticInformation`
      return false unless type

      pushing_type(type) do
        node.members.each &.accept(self)
      end

      false
    end

    def visit(node) : Bool
      @rule.test(@source, node, current_type)

      true
    end

    private def pushing_type(type : Crystal::ModuleType, &)
      old_type = @current_type
      @current_type = type
      yield
      @current_type = old_type
    end
  end
end
