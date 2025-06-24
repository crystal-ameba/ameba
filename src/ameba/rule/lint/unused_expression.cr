module Ameba::Rule::Lint
  class UnusedExpression < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused expressions"
    end

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    CLASS_VAR_MSG = "Value from class variable access is unused"

    def test(source, node : Crystal::ClassVar, in_macro : Bool)
      # Class variables aren't supported in macros
      return if in_macro

      issue_for node, CLASS_VAR_MSG
    end

    COMPARISON_MSG       = "Comparison operation is unused"
    COMPARISON_OPERATORS = %w[== != < <= > >= <=>]

    MSG_GENERIC = "Generic is not used"
    MSG_UNION   = "Union is not used"

    def test(source, node : Crystal::Call, in_macro : Bool)
      if node.name.in?(COMPARISON_OPERATORS) && node.args.size == 1
        issue_for node, COMPARISON_MSG
      end

      if path_or_generic_union?(node)
        issue_for node, MSG_UNION
      end
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

    INSTANCE_VAR_MSG = "Value from instance variable access is unused"

    def test(source, node : Crystal::InstanceVar, in_macro : Bool)
      # Handle special case when using `@type` within a method body has side-effects
      return if in_macro && node.name == "@type"

      issue_for node, INSTANCE_VAR_MSG
    end

    LITERAL_MSG = "Literal value is not used"

    def test(source, node : Crystal::RegexLiteral, in_macro : Bool)
      # Locations for Regex literals were added in Crystal v1.15.0
      {% if compare_versions(Crystal::VERSION, "1.15.0") >= 0 %}
        issue_for node, LITERAL_MSG
      {% end %}
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
      issue_for node, LITERAL_MSG
    end

    LOCAL_VAR_MSG = "Value from local variable access is unused"

    SELF_MSG = "`self` is not used"

    def test(source, node : Crystal::Var, in_macro : Bool)
      if node.name == "self"
        issue_for node, SELF_MSG
        return
      end

      # Ignore `debug` and `skip_file` macro methods
      return if in_macro && node.name.in?("debug", "skip_file")

      issue_for node, LOCAL_VAR_MSG
    end

    PSEUDO_METHOD_MSG = "Pseudo-method call is not used"

    def test(
      source,
      node : Crystal::PointerOf | Crystal::SizeOf | Crystal::InstanceSizeOf |
             Crystal::AlignOf | Crystal::InstanceAlignOf | Crystal::OffsetOf |
             Crystal::IsA | Crystal::NilableCast | Crystal::RespondsTo | Crystal::Not,
      in_macro : Bool,
    )
      issue_for node, PSEUDO_METHOD_MSG
    end
  end
end
