module Ameba::Rule::Lint
  # A rule that disallows useless comparisons.
  #
  # For example, this is considered invalid:
  #
  # ```
  # a = obj.method do |x|
  #   x == 1 # => Comparison operation has no effect
  #   puts x
  # end
  #
  # b = if a >= 0
  #       c < 1 # => Comparison operation has no effect
  #       "hello world"
  #     end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a = obj.method do |x|
  #   x == 1
  # end
  #
  # b = if a >= 0 &&
  #        c < 1
  #       "hello world"
  #     end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UselessComparison:
  #   Enabled: true
  # ```
  class UselessComparison < Base
    properties do
      description "Disallows useless comparison operations"
    end

    MSG = "Comparison operation has no effect"

    COMPARISON_OPERATORS = %w(
      == != =~ !~ ===
      < <= > >= <=>
    )

    def test(source : Source)
      ImplicitReturnVisitor.new self, source
    end

    def test(source, node : Crystal::Call, last_is_used : Bool)
      return if last_is_used

      if node.name.in?(COMPARISON_OPERATORS) && node.args.size == 1
        issue_for node, MSG
      end
    end

    private class ImplicitReturnVisitor < AST::NodeVisitor
      # When greater than zero, indicates the current node's return value is ignored
      @stack : Int32 = 0

      def visit(node : Crystal::Expressions) : Nil
        last_idx = node.expressions.size - 1

        swap_stack do |old_stack|
          node.expressions.each_with_index do |exp, idx|
            if idx == last_idx && old_stack > 0
              incr_stack { exp.accept(self) }
            else
              exp.accept(self)
            end
          end
        end
      end

      def visit(node : Crystal::Call) : Nil
        node.obj.try &.accept(self)

        @rule.test(@source, node, @stack > 0)

        incr_stack {
          node.args.each &.accept(self)
          node.named_args.try &.each &.accept(self)
          node.block_arg.try &.accept(self)
          node.block.try &.accept(self)
        }
      end

      def visit(node : Crystal::Assign | Crystal::OpAssign) : Nil
        incr_stack { node.value.accept(self) }
      end

      def visit(node : Crystal::MultiAssign) : Nil
        node.targets.each &.accept(self)

        incr_stack { node.values.each &.accept(self) }
      end

      def visit(node : Crystal::If | Crystal::Unless) : Nil
        incr_stack { node.cond.accept(self) }

        node.then.accept(self)
        node.else.accept(self)
      end

      def visit(node : Crystal::While | Crystal::Until) : Nil
        incr_stack { node.cond.accept(self) }

        node.body.accept(self)
      end

      def visit(node : Crystal::Def) : Nil
        incr_stack {
          node.args.each &.accept(self)
          node.double_splat.try &.accept(self)
          node.block_arg.try &.accept(self)
          node.body.accept(self)
        }
      end

      def visit(node : Crystal::Macro | Crystal::MacroIf | Crystal::MacroFor) : Nil
      end

      def visit(node : Crystal::ArrayLiteral | Crystal::TupleLiteral) : Nil
        incr_stack { node.elements.each &.accept(self) }
      end

      def visit(node : Crystal::HashLiteral | Crystal::NamedTupleLiteral) : Nil
        incr_stack { node.entries.each &.value.accept(self) }
      end

      def visit(node : Crystal::Case) : Nil
        incr_stack { node.cond.try &.accept(self) }
        node.whens.each &.accept(self)
        node.else.try &.accept(self)
      end

      def visit(node : Crystal::Select) : Nil
        node.whens.each &.accept(self)
        node.else.try &.accept(self)
      end

      def visit(node : Crystal::Rescue) : Nil
        swap_stack { node.body.accept(self) }
      end

      def visit(node : Crystal::ExceptionHandler) : Nil
        if node.else.nil?
          incr_stack { node.body.accept(self) }
        else
          node.body.accept(self)
        end

        incr_stack {
          node.rescues.try &.each &.accept(self)
          node.else.try &.accept(self)
          node.ensure.try &.accept(self)
        }
      end

      def visit(node : Crystal::ControlExpression) : Nil
        incr_stack { node.exp.try &.accept(self) }
      end

      def incr_stack(&) : Nil
        @stack += 1
        yield
        @stack -= 1
      end

      def swap_stack(& : Int32 -> Nil) : Nil
        old_stack = @stack
        @stack = 0
        yield old_stack
        @stack = old_stack
      end
    end
  end
end
