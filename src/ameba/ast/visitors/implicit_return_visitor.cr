module Ameba::AST
  # AST visitor that finds nodes that are not used by their surrounding scope.
  #
  # A stack is used to keep track of when a node is used, incrementing every time
  # something will capture its implicit (or explicit) return value, such as the
  # path in a class name or the value in an assign.
  #
  # This also allows for passing through whether a node is captured from a nodes
  # parent to its children, such as from an `if` statements parent to it's body,
  # as the body is not used by the `if` itself, but by its parent scope.
  class ImplicitReturnVisitor < BaseVisitor
    # When greater than zero, indicates the current node's return value is used
    @stack : Int32 = 0

    # The stack is swapped out here as `Crystal::Expressions` are isolated from
    # their parents scope. Only the last line in an expressions node can be
    # captured by their parent node.
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

    def visit(node : Crystal::BinaryOp) : Bool
      @rule.test(@source, node, @stack > 0)

      if node.right.is_a?(Crystal::Call)
        incr_stack { node.left.accept(self) }
      else
        node.left.accept(self)
      end

      node.right.accept(self)

      false
    end

    def visit(node : Crystal::Call) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack do
        node.obj.try &.accept(self)
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

    def visit(node : Crystal::ClassDef) : Bool
      incr_stack do
        node.name.accept(self)
        node.superclass.try &.accept(self)
      end

      node.body.accept(self)

      false
    end

    def visit(node : Crystal::FunDef) : Bool
      incr_stack do
        node.args.each &.accept(self)
        node.return_type.try &.accept(self)
        node.body.try &.accept(self)
      end

      false
    end

    def visit(node : Crystal::ExternalVar) : Bool
      incr_stack { node.type_spec.accept(self) }

      false
    end

    def visit(node : Crystal::Include | Crystal::Extend) : Bool
      incr_stack do
        node.name.accept(self)
      end

      false
    end

    def visit(node : Crystal::Cast | Crystal::NilableCast) : Bool
      node.obj.accept(self)
      incr_stack { node.to.accept(self) }

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
      @rule.test(@source, node, @stack > 0)

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
        incr_stack { exp.accept(self) }
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

    def visit(node : Crystal::RegexLiteral) : Bool
      @rule.test(@source, node, @stack > 0)

      # Regex literals either contain string literals or string interpolations,
      # both of which are "captured" by the parent regex literal
      incr_stack { node.value.accept(self) }

      false
    end

    def visit(
      node : Crystal::BoolLiteral | Crystal::CharLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral | Crystal::ProcLiteral,
    ) : Bool
      @rule.test(@source, node, @stack > 0)

      true
    end

    def visit(node : Crystal::Yield) : Bool
      @rule.test(@source, node, @stack > 0)

      incr_stack { node.exps.each &.accept(self) }

      false
    end

    def visit(node : Crystal::Generic | Crystal::Path | Crystal::Union) : Bool
      @rule.test(@source, node, @stack > 0)

      false
    end

    def visit(node : Crystal::Alias)
      @rule.test(@source, node, @stack > 0)

      incr_stack do
        node.name.accept(self)
        node.value.accept(self)
      end

      false
    end

    def visit(node : Crystal::TypeDef)
      @rule.test(@source, node, @stack > 0)

      incr_stack do
        node.type_spec.accept(self)
      end

      false
    end

    # Indicates that any nodes visited within the block are captured / used.
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
