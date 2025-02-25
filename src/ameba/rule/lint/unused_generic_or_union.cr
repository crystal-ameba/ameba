module Ameba::Rule::Lint
  # A rule that disallows unused generics or unions (`String?`, `StaticArray(Int32, 10)`, etc).
  #
  # For example, these are considered invalid:
  #
  # ```
  # String?
  #
  # Float64 | StaticArray(Float64, 10)
  #
  # def size
  #   Float64 | Int32
  #   0.1
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a : Int32 = 10
  #
  # klass = String?
  #
  # alias MyType = Float64 | StaticArray(Float64, 10)
  #
  # def size : Float64
  #   0.1
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedGenericOrUnion:
  #   Enabled: true
  # ```
  class UnusedGenericOrUnion < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused generics or unions"
    end

    MSG_GENERIC = "Generic is not used"
    MSG_UNION   = "Union is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Call, in_macro : Bool)
      issue_for node, MSG_UNION if path_or_generic_union?(node)
    end

    def test(source, node : Crystal::Generic, in_macro : Bool)
      issue_for node, MSG_GENERIC
    end

    private def path_or_generic_union?(node : Crystal::Call) : Bool
      node.name == "|" && node.args.size == 1 && !!(obj = node.obj) &&
        valid_type_node?(obj) && valid_type_node?(node.args.first)
    end

    private def valid_type_node?(node : Crystal::ASTNode) : Bool
      case node
      when Crystal::Path, Crystal::Generic, Crystal::Self, Crystal::TypeOf, Crystal::Underscore
        true
      when Crystal::Var
        node.name == "self"
      when Crystal::Call
        path_or_generic_union?(node)
      else
        false
      end
    end
  end
end
