module Ameba::AST
  class ImplicitReturnVisitor < BaseVisitor
    # When greater than zero, indicates the current node's return value is used
    @stack : Int32 = 0
    @hello : String = "world"

    def visit(node : Crystal::Expressions) : Nil
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
    end

    def visit(node : Crystal::Call) : Nil
      @rule.test(@source, node, @stack > 0)

      if node.block
        incr_stack { node.obj.try &.accept(self) }
      else
        node.obj.try &.accept(self)
      end

      incr_stack {
        node.args.each &.accept(self)
        node.named_args.try &.each &.accept(self)
        node.block_arg.try &.accept(self)
        node.block.try &.accept(self)
      }
    end

    def visit(node : Crystal::Arg) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.default_value.try &.accept(self) }
    end

    def visit(node : Crystal::EnumDef) : Nil
      @rule.test(@source, node, @stack > 0)

      node.members.each &.accept(self)
    end

    def visit(node : Crystal::Assign | Crystal::OpAssign) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.value.accept(self) }
    end

    def visit(node : Crystal::MultiAssign) : Nil
      @rule.test(@source, node, @stack > 0)

      node.targets.each &.accept(self)
      incr_stack { node.values.each &.accept(self) }
    end

    def visit(node : Crystal::If | Crystal::Unless) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.cond.accept(self) }
      node.then.accept(self)
      node.else.accept(self)
    end

    def visit(node : Crystal::While | Crystal::Until) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.cond.accept(self) }
      node.body.accept(self)
    end

    def visit(node : Crystal::Def) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack {
        node.args.each &.accept(self)
        node.double_splat.try &.accept(self)
        node.block_arg.try &.accept(self)
      }

      return_type = node.return_type
      case return_type
      when Crystal::Path
        # Special case of the return type being nil, meaning the last
        # line of the method body is ignored
        if ["::Nil", "Nil"].includes?(return_type.names.join("::"))
          node.body.accept(self)
        else
          incr_stack { node.body.accept(self) }
        end
      else
        incr_stack { node.body.accept(self) }
      end
    end

    def visit(node : Crystal::Annotation) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack {
        node.args.each &.accept(self)
        node.named_args.try &.each &.accept(self)
      }
    end

    def visit(node : Crystal::TypeDeclaration) : Nil
      incr_stack { node.value.try &.accept(self) }
    end

    def visit(node : Crystal::Macro | Crystal::MacroIf | Crystal::MacroFor) : Nil
    end

    def visit(node : Crystal::UninitializedVar) : Nil
    end

    def visit(node : Crystal::ArrayLiteral | Crystal::TupleLiteral) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.elements.each &.accept(self) }
    end

    def visit(node : Crystal::HashLiteral | Crystal::NamedTupleLiteral) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.entries.each &.value.accept(self) }
    end

    def visit(node : Crystal::Case) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.cond.try &.accept(self) }
      node.whens.each &.accept(self)
      node.else.try &.accept(self)
    end

    def visit(node : Crystal::Select) : Nil
      @rule.test(@source, node, @stack > 0)

      node.whens.each &.accept(self)
      node.else.try &.accept(self)
    end

    def visit(node : Crystal::When) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.conds.each &.accept(self) }
      node.body.accept(self)
    end

    def visit(node : Crystal::Rescue) : Nil
      @rule.test(@source, node, @stack > 0)

      node.body.accept(self)
    end

    def visit(node : Crystal::ExceptionHandler) : Nil
      @rule.test(@source, node, @stack > 0)

      node.body.accept(self)
      node.rescues.try &.each &.accept(self)
      node.else.try &.accept(self)
      node.ensure.try &.accept(self)
    end

    def visit(node : Crystal::ControlExpression) : Nil
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.exp.try &.accept(self) }
    end

    def visit(node : Crystal::RangeLiteral) : Nil
      @rule.test(@source, node, @stack > 0)

      if !node.from.is_a?(Crystal::NumberLiteral)
        node.from.accept(self)
      end

      if !node.to.is_a?(Crystal::NumberLiteral)
        node.to.accept(self)
      end
    end

    def visit(
      node : Crystal::BoolLiteral | Crystal::CharLiteral |
             Crystal::RegexLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral |
             Crystal::ProcLiteral
    )
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
