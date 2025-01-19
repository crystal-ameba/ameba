module Ameba::Rule::Lint
  # A rule that disallows unused constants, generics, or unions (`Int32`, `String?`, `StaticArray(Int32, 10)`, etc).
  #
  # For example, these are considered invalid:
  #
  # ```
  # Int32
  #
  # String?
  #
  # Float64 | StaticArray(Float64, 10)
  #
  # def size
  #   Float64
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
  # Lint/UnusedTypeOrConstant:
  #   Enabled: true
  # ```
  class UnusedTypeOrConstant < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused literal values"
    end

    MSG = "Type or constant is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Call, last_is_used : Bool)
      return if last_is_used || !path_or_generic_union?(node)

      issue_for node, MSG
    end

    def test(source, node : Crystal::Path | Crystal::Generic | Crystal::Union, last_is_used : Bool)
      issue_for node, MSG unless last_is_used
    end

    def path_or_generic_union?(node : Crystal::Call) : Bool
      return false unless node.name == "|" && node.args.size == 1

      case lhs = node.obj
      when Crystal::Path, Crystal::Generic
        # Okay
      when Crystal::Call
        return false unless path_or_generic_union?(lhs)
      else
        return false
      end

      case rhs = node.args.first?
      when Crystal::Path, Crystal::Generic
        # Okay
      when Crystal::Call
        return false unless path_or_generic_union?(rhs)
      else
        return false
      end

      true
    end
  end
end
