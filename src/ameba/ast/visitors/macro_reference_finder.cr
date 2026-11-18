module Ameba::AST
  # Finds references to a (runtime) variable within the macros of a node.
  #
  # NOTE: Identifiers within the macro code (`{{ ... }}`, `{% ... %}`) refer
  # to the macro variables, never to the runtime ones, hence the macro code
  # can reference a variable only via an identifier built from a string or
  # a symbol (i.e. `{{ "foo".id }}`), while the rest of the macro body
  # is a plain code (i.e. `{% if flag?(:foo) %} foo {% end %}`).
  class MacroReferenceFinder < Crystal::Visitor
    # Collects the values of string and symbol literals, which might end up
    # being an identifier (i.e. via `#id` method)
    private class StringValues < Crystal::Visitor
      # Comparison operators, returning either a boolean or a number
      COMPARISON_OPERATORS = %w[== != =~ !~ < <= > >= === <=>]

      getter values = [] of String

      def initialize(node)
        node.accept(self)
      end

      def visit(node : Crystal::StringLiteral | Crystal::SymbolLiteral)
        @values << node.value
        false
      end

      # Skips the calls to predicates (i.e. `flag?(:foo)`) and comparisons
      # (i.e. `x == "foo"`), as their results can't be an identifier
      def visit(node : Crystal::Call)
        !(node.name.ends_with?('?') || node.name.in?(COMPARISON_OPERATORS))
      end

      def visit(node : Crystal::ASTNode)
        true
      end
    end

    property? references = false

    @reference : Regex
    @scanner = MacroCodeScanner.new

    def initialize(node, reference : String)
      # Matches *reference* as a whole identifier, so that i.e. `b` isn't
      # found within `blk`, `@b`, or `b?`, but still within `b.foo` or `b != c`.
      #
      # Method names (`a.b`, `a&.b`, `def b`, `macro b`), named arguments
      # (`a(b: 1)`) and named-tuple keys (`{b: 1}`) are skipped, while
      # ranges (`1..b`) and paths (`b::C`) aren't.
      @reference = /
        (?<![\p{L}\p{N}_@$]|[^.]\.|^\.|\bdef\s|\bmacro\s)
        #{Regex.escape(reference)}
        (?![\p{L}\p{N}_?]|!(?![=~])|:(?!:))
        /x
      node.accept(self)
    end

    @[AlwaysInline]
    private def includes_reference?(code : String) : Bool
      code.matches?(@reference)
    end

    # Returns `true` if the macro code *node* references the variable
    private def macro_code_references?(node : Crystal::ASTNode) : Bool
      StringValues.new(node).values.any? { |value| includes_reference?(value) }
    end

    def visit(node : Crystal::MacroLiteral)
      !(@references ||= includes_reference?(@scanner.scan(node.value)))
    end

    def visit(node : Crystal::MacroExpression)
      @scanner.after_value! if node.output?

      !(@references ||= macro_code_references?(node.exp))
    end

    def visit(node : Crystal::MacroFor)
      !(@references ||= macro_code_references?(node.exp))
    end

    def visit(node : Crystal::MacroIf)
      return false if @references ||= macro_code_references?(node.cond)

      # Both branches start in the same lexical state
      scanner = @scanner.clone
      node.then.accept(self)

      unless node.else.is_a?(Crystal::Nop)
        @scanner = scanner
        node.else.accept(self)
      end
      false
    end

    def visit(node : Crystal::ASTNode)
      true
    end
  end
end
