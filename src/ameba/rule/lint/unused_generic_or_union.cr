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

    MSG = "Generic or union is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Call, node_is_used : Bool)
      return if node_is_used || !path_or_generic_union?(node)

      issue_for node, MSG
    end

    def test(source, node : Crystal::Generic | Crystal::Union, node_is_used : Bool)
      issue_for node, MSG unless node_is_used
    end

    def path_or_generic_union?(node : Crystal::Call) : Bool
      return false unless node.name == "|" && node.args.size == 1

      case lhs = node.obj
      when Crystal::Path, Crystal::Generic, Crystal::Self, Crystal::TypeOf, Crystal::Underscore
        # Okay
      when Crystal::Var
        return false unless lhs.name == "self"
      when Crystal::Call
        return false unless (lhs.name == "self") || path_or_generic_union?(lhs)
      else
        return false
      end

      case rhs = node.args.first?
      when Crystal::Path, Crystal::Generic, Crystal::Self, Crystal::TypeOf, Crystal::Underscore
        # Okay
      when Crystal::Var
        return false unless rhs.name == "self"
      when Crystal::Call
        return false unless (rhs.name == "self") || path_or_generic_union?(rhs)
      else
        return false
      end

      true
    end
  end
end
