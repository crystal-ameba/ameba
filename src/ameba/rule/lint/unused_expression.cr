module Ameba::Rule::Lint
  # A rule that disallows unused expressions.
  #
  # For example, this is considered invalid:
  #
  # ```
  # a = obj.method do |x|
  #   x == 1 # => Comparison operation has no effect
  #   puts x
  # end
  #
  # Float64 | StaticArray(Float64, 10)
  #
  # pointerof(foo)
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a = obj.method do |x|
  #   x == 1
  # end
  #
  # foo : Float64 | StaticArray(Float64, 10) = 0.1
  #
  # bar = pointerof(foo)
  # ```
  #
  # This rule currently supports checking for unused:
  # - comparison operators: `<`, `>=`, etc.
  # - generics and unions: `String?`, `Int32 | Float64`, etc.
  # - literals: strings, bools, chars, hashes, arrays, range, etc.
  # - pseudo-method calls: `sizeof`, `is_a?` etc.
  # - variable access: local, `@ivar`, `@@cvar` and `self`
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedExpression:
  #   Enabled: true
  # ```
  class UnusedExpression < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused expressions"
    end

    COMPARISON_OPERATORS = %w[== != < <= > >= <=>]

    MSG_CLASS_VAR     = "Class variable access is unused"
    MSG_COMPARISON    = "Comparison operation is unused"
    MSG_GENERIC       = "Generic type is unused"
    MSG_UNION         = "Union type is unused"
    MSG_INSTANCE_VAR  = "Instance variable access is unused"
    MSG_LITERAL       = "Literal value is unused"
    MSG_LOCAL_VAR     = "Local variable access is unused"
    MSG_SELF          = "`self` access is unused"
    MSG_PSEUDO_METHOD = "Pseudo-method call is unused"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::ClassVar, in_macro : Bool)
      # Class variables aren't supported in macros
      return if in_macro

      issue_for node, MSG_CLASS_VAR
    end

    def test(source, node : Crystal::Call, in_macro : Bool)
      if node.name.in?(COMPARISON_OPERATORS) && node.args.size == 1
        issue_for node, MSG_COMPARISON
      end

      if path_or_generic_union?(node)
        issue_for node, MSG_UNION
      end
    end

    def test(source, node : Crystal::Generic, in_macro : Bool)
      issue_for node, MSG_GENERIC
    end

    def test(source, node : Crystal::InstanceVar, in_macro : Bool)
      # Handle special case when using `@type` within a method body has side-effects
      return if in_macro && node.name == "@type"

      issue_for node, MSG_INSTANCE_VAR
    end

    def test(source, node : Crystal::RegexLiteral, in_macro : Bool)
      issue_for node, MSG_LITERAL
    end

    def test(
      source,
      node : Crystal::BoolLiteral | Crystal::CharLiteral | Crystal::HashLiteral |
             Crystal::ProcLiteral | Crystal::ArrayLiteral | Crystal::RangeLiteral |
             Crystal::TupleLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral |
             Crystal::NamedTupleLiteral | Crystal::StringInterpolation,
      in_macro : Bool,
    )
      issue_for node, MSG_LITERAL
    end

    def test(source, node : Crystal::Var, in_macro : Bool)
      if node.name == "self"
        issue_for node, MSG_SELF
        return
      end

      # Ignore `debug` and `skip_file` macro methods
      return if in_macro && node.name.in?("debug", "skip_file")

      issue_for node, MSG_LOCAL_VAR
    end

    def test(
      source,
      node : Crystal::PointerOf | Crystal::SizeOf | Crystal::InstanceSizeOf |
             Crystal::AlignOf | Crystal::InstanceAlignOf | Crystal::OffsetOf |
             Crystal::IsA | Crystal::NilableCast | Crystal::RespondsTo | Crystal::Not,
      in_macro : Bool,
    )
      issue_for node, MSG_PSEUDO_METHOD
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
