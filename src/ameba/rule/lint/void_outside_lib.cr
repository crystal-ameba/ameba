module Ameba::Rule::Lint
  # A rule that disallows uses of `Void` outside C lib bindings.
  # Usages of these outside of C lib bindings don't make sense,
  # and can sometimes break the compiler. `Nil` should be used instead in these cases.
  # `Pointer(Void)` is the only case that's allowed per this rule.
  #
  # These are considered invalid:
  #
  # ```
  # def foo(bar : Void) : Slice(Void)?
  # end
  #
  # alias Baz = Void
  #
  # struct Qux < Void
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/VoidOutsideLib:
  #   Enabled: true
  # ```
  class VoidOutsideLib < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows use of `Void` outside C lib bindings and `Pointer(Void)`"
    end

    MSG = "`Void` is not allowed in this context"

    def test(source)
      PathGenericUnionVisitor.new self, source, skip: [Crystal::LibDef]
    end

    def test(source, node : Crystal::Path)
      return unless path_named?(node, "Void")

      issue_for node, MSG
    end

    def test(source, node : Crystal::Generic)
      # Specifically only allow `Pointer(Void)`
      return if path_named?(node.name, "Pointer") &&
                node.type_vars.size == 1 &&
                path_named?(node.type_vars.first, "Void")

      if path_named?(node.name, "Void")
        issue_for node, MSG, prefer_name_location: true
      end

      node.type_vars.each do |type_var|
        test(source, type_var)
      end
    end

    def test(source, node : Crystal::Union)
      node.types.each do |type|
        test(source, type)
      end
    end

    private class PathGenericUnionVisitor < AST::NodeVisitor
      def visit(node : Crystal::Generic | Crystal::Path | Crystal::Union)
        return false if skip?(node)

        @rule.test @source, node
        false
      end
    end
  end
end
