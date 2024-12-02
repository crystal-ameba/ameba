module Ameba::AST
  class ImplicitReturnVisitor < BaseVisitor
    # When greater than zero, indicates the current node's return value is used
    @stack : Int32 = 0

    def visit(node : Crystal::Expressions) : Bool
      @rule.test(@source, node, @stack > 0)

      last_idx = node.expressions.size - 1

      swap_stack do |old_stack|
        node.expressions.each_with_index do |exp, idx|
          if exp.is_a?(Crystal::ControlExpression)
            incr_stack { exp.accept(self) }
            break
          elsif idx == last_idx && old_stack > 0
            incr_stack { exp.accept(self) }
          else
            exp.accept(self)
          end
        end
      end

      false
    end

    def visit(node : Crystal::Call) : Bool
      @rule.test(@source, node, @stack > 0)

      if node.block
        incr_stack { node.obj.try &.accept(self) }
      else
        node.obj.try &.accept(self)
      end

      incr_stack do
        node.args.each &.accept(self)
        node.named_args.try &.each &.accept(self)
        node.block_arg.try &.accept(self)
        node.block.try &.accept(self)
      end

      false
    end

    def visit(node : Crystal::Arg) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.default_value.try &.accept(self) }

      false
    end

    def visit(node : Crystal::EnumDef) : Bool
      @rule.test(@source, node, @stack > 0)

      node.members.each &.accept(self)

      false
    end

    def visit(node : Crystal::Assign | Crystal::OpAssign) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.value.accept(self) }

      false
    end

    def visit(node : Crystal::MultiAssign) : Bool
      @rule.test(@source, node, @stack > 0)

      node.targets.each &.accept(self)
      incr_stack { node.values.each &.accept(self) }

      false
    end

    def visit(node : Crystal::If | Crystal::Unless) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.cond.accept(self) }
      node.then.accept(self)
      node.else.accept(self)

      false
    end

    def visit(node : Crystal::While | Crystal::Until) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.cond.accept(self) }
      node.body.accept(self)

      false
    end

    def visit(node : Crystal::Def) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack do
        node.args.each &.accept(self)
        node.double_splat.try &.accept(self)
        node.block_arg.try &.accept(self)
      end

      if (return_type = node.return_type).is_a?(Crystal::Path)
        # Special case of the return type being nil, meaning the last
        # line of the method body is ignored
        if return_type.names.join("::").in?("::Nil", "Nil")
          node.body.accept(self)
        else
          incr_stack { node.body.accept(self) }
        end
      else
        incr_stack { node.body.accept(self) }
      end

      false
    end

    def visit(node : Crystal::Annotation) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack do
        node.args.each &.accept(self)
        node.named_args.try &.each &.accept(self)
      end

      false
    end

    def visit(node : Crystal::TypeDeclaration) : Bool
      incr_stack { node.value.try &.accept(self) }

      false
    end

    def visit(node : Crystal::Macro | Crystal::MacroIf | Crystal::MacroFor) : Bool
      false
    end

    def visit(node : Crystal::UninitializedVar) : Bool
      false
    end

    def visit(node : Crystal::ArrayLiteral | Crystal::TupleLiteral) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.elements.each &.accept(self) }

      false
    end

    def visit(node : Crystal::StringInterpolation) : Bool
      @rule.test(@source, node, @stack > 0)

      node.expressions.each do |exp|
        unless exp.is_a?(Crystal::StringLiteral)
          incr_stack { exp.accept(self) }
        end
      end

      false
    end

    def visit(node : Crystal::HashLiteral | Crystal::NamedTupleLiteral) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.entries.each &.value.accept(self) }

      false
    end

    def visit(node : Crystal::Case) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.cond.try &.accept(self) }
      node.whens.each &.accept(self)
      node.else.try &.accept(self)

      false
    end

    def visit(node : Crystal::Select) : Bool
      @rule.test(@source, node, @stack > 0)

      node.whens.each &.accept(self)
      node.else.try &.accept(self)

      false
    end

    def visit(node : Crystal::When) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.conds.each &.accept(self) }
      node.body.accept(self)

      false
    end

    def visit(node : Crystal::Rescue) : Bool
      @rule.test(@source, node, @stack > 0)

      node.body.accept(self)

      false
    end

    def visit(node : Crystal::ExceptionHandler) : Bool
      @rule.test(@source, node, @stack > 0)

      node.body.accept(self)
      node.rescues.try &.each &.accept(self)
      node.else.try &.accept(self)
      node.ensure.try &.accept(self)

      false
    end

    def visit(node : Crystal::ControlExpression) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.exp.try &.accept(self) }

      false
    end

    def visit(node : Crystal::RangeLiteral) : Bool
      @rule.test(@source, node, @stack > 0)

      unless node.from.is_a?(Crystal::NumberLiteral)
        node.from.accept(self)
      end

      unless node.to.is_a?(Crystal::NumberLiteral)
        node.to.accept(self)
      end

      false
    end

    def visit(
      node : Crystal::BoolLiteral | Crystal::CharLiteral |
             Crystal::RegexLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral |
             Crystal::ProcLiteral,
    ) : Bool
      @rule.test(@source, node, @stack > 0)

      true
    end

    private def incr_stack(&) : Nil
      @stack += 1
      yield
      @stack -= 1
    end

    private def swap_stack(& : Int32 -> Nil) : Nil
      old_stack = @stack
      @stack = 0
      yield old_stack
      @stack = old_stack
    end
  end
end
