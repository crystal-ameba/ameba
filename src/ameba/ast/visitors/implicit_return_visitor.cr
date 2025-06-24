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
    @in_macro : Bool = false

    # The stack is swapped out here as `Crystal::Expressions` are isolated from
    # their parents scope. Only the last line in an expressions node can be
    # captured by their parent node.
    def visit(node : Crystal::Expressions) : Bool
      report_implicit_return(node)

      last_idx = node.expressions.size - 1

      swap_stack do |old_stack|
        node.expressions.each_with_index do |exp, idx|
          if exp.is_a?(Crystal::ControlExpression)
            incr_stack { exp.accept(self) }
            break
          elsif idx == last_idx && old_stack.positive?
            incr_stack { exp.accept(self) }
          else
            exp.accept(self)
          end
        end
      end

      false
    end

    def visit(node : Crystal::BinaryOp) : Bool
      report_implicit_return(node)

      case node.right
      when Crystal::Call, Crystal::Expressions, Crystal::ControlExpression
        incr_stack { node.left.accept(self) }
      else
        node.left.accept(self)
      end
      node.right.accept(self)

      false
    end

    def visit(node : Crystal::Call) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::Arg) : Bool
      report_implicit_return(node)

      incr_stack { node.default_value.try &.accept(self) }

      false
    end

    def visit(node : Crystal::EnumDef) : Bool
      report_implicit_return(node)

      node.members.each &.accept(self)

      false
    end

    def visit(node : Crystal::Assign | Crystal::OpAssign) : Bool
      report_implicit_return(node)

      incr_stack { node.value.accept(self) }

      false
    end

    def visit(node : Crystal::MultiAssign) : Bool
      report_implicit_return(node)

      incr_stack { node.values.each &.accept(self) }

      false
    end

    def visit(node : Crystal::If | Crystal::Unless) : Bool
      report_implicit_return(node)

      incr_stack { node.cond.accept(self) }
      node.then.accept(self)
      node.else.accept(self)

      false
    end

    def visit(node : Crystal::While | Crystal::Until) : Bool
      report_implicit_return(node)

      incr_stack { node.cond.accept(self) }
      node.body.accept(self)

      false
    end

    def visit(node : Crystal::Def) : Bool
      report_implicit_return(node)

      incr_stack do
        node.args.each &.accept(self)
        node.double_splat.try &.accept(self)
        node.block_arg.try &.accept(self)
      end

      case
      when node.name == "initialize",
           node.return_type.as?(Crystal::Path).try(&.names.join("::").in?("::Nil", "Nil"))
        # Special case of the return type being nil, meaning the last
        # line of the method body is ignored
        # Last line of initialize methods are also ignored
        swap_stack { node.body.accept(self) }
      else
        incr_stack { node.body.accept(self) }
      end

      false
    end

    def visit(node : Crystal::Macro) : Bool
      report_implicit_return(node)

      incr_stack do
        node.args.each &.accept(self)
        node.double_splat.try &.accept(self)
        node.block_arg.try &.accept(self)
      end

      swap_stack do
        node.body.accept(self)
      end

      false
    end

    def visit(node : Crystal::ClassDef | Crystal::ModuleDef) : Bool
      report_implicit_return(node)

      node.body.accept(self)

      false
    end

    def visit(node : Crystal::FunDef) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::Cast | Crystal::NilableCast | Crystal::IsA | Crystal::RespondsTo) : Bool
      report_implicit_return(node)

      incr_stack { node.obj.accept(self) }

      false
    end

    def visit(node : Crystal::UnaryExpression) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::TypeOf) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::Annotation) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::TypeDeclaration) : Bool
      report_implicit_return(node)

      incr_stack { node.value.try &.accept(self) }

      false
    end

    def visit(node : Crystal::ArrayLiteral | Crystal::TupleLiteral) : Bool
      report_implicit_return(node)

      incr_stack { node.elements.each &.accept(self) }

      false
    end

    def visit(node : Crystal::StringInterpolation) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::HashLiteral | Crystal::NamedTupleLiteral) : Bool
      report_implicit_return(node)

      incr_stack { node.entries.each &.value.accept(self) }

      false
    end

    def visit(node : Crystal::Case) : Bool
      report_implicit_return(node)

      incr_stack { node.cond.try &.accept(self) }
      node.whens.each &.accept(self)
      node.else.try &.accept(self)

      false
    end

    def visit(node : Crystal::Select) : Bool
      report_implicit_return(node)

      node.accept_children(self)

      false
    end

    def visit(node : Crystal::When) : Bool
      report_implicit_return(node)

      incr_stack { node.conds.each &.accept(self) }
      node.body.accept(self)

      false
    end

    def visit(node : Crystal::Rescue) : Bool
      report_implicit_return(node)

      node.body.accept(self)

      false
    end

    def visit(node : Crystal::ExceptionHandler) : Bool
      report_implicit_return(node)

      if node.else
        # Last line of body isn't implicitly returned if there's an else
        swap_stack { node.body.try &.accept(self) }
      else
        node.body.accept(self)
      end

      node.rescues.try &.each &.accept(self)
      node.else.try &.accept(self)

      # Last line of ensure isn't implicitly returned
      swap_stack { node.ensure.try &.accept(self) }

      false
    end

    def visit(node : Crystal::Block) : Bool
      report_implicit_return(node)

      node.body.accept(self)

      false
    end

    def visit(node : Crystal::ControlExpression) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::RangeLiteral) : Bool
      report_implicit_return(node)

      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::RegexLiteral) : Bool
      report_implicit_return(node)

      # Regex literals either contain string literals or string interpolations,
      # both of which are "captured" by the parent regex literal
      incr_stack { node.accept_children(self) }

      false
    end

    def visit(node : Crystal::Yield) : Bool
      report_implicit_return(node)

      incr_stack { node.exps.each &.accept(self) }

      false
    end

    def visit(node : Crystal::MacroExpression) : Bool
      report_implicit_return(node)

      in_macro do
        if node.output?
          incr_stack { node.exp.accept(self) }
        else
          swap_stack { node.exp.accept(self) }
        end
      end

      false
    end

    def visit(node : Crystal::MacroIf) : Bool
      report_implicit_return(node)

      in_macro do
        swap_stack do
          incr_stack { node.cond.accept(self) }
          node.then.accept(self)
          node.else.accept(self)
        end
      end

      false
    end

    def visit(node : Crystal::MacroFor) : Bool
      report_implicit_return(node)

      in_macro do
        swap_stack { node.body.accept(self) }
      end

      false
    end

    def visit(node : Crystal::Alias | Crystal::TypeDef | Crystal::MacroVar)
      false
    end

    def visit(node : Crystal::Generic | Crystal::Path | Crystal::Union | Crystal::UninitializedVar | Crystal::OffsetOf | Crystal::LibDef | Crystal::Include | Crystal::Extend) : Bool
      report_implicit_return(node)

      false
    end

    def visit(node)
      report_implicit_return(node)

      true
    end

    private def report_implicit_return(node) : Nil
      @rule.test(@source, node, @in_macro) unless @stack.positive?
    end

    # Indicates that any nodes visited within the block are captured / used.
    private def incr_stack(&) : Nil
      @stack += 1
      yield
    ensure
      @stack -= 1
    end

    private def swap_stack(& : Int32 -> Nil) : Nil
      old_stack = @stack
      @stack = 0
      begin
        yield old_stack
      ensure
        @stack = old_stack
      end
    end

    private def in_macro(&) : Nil
      old_value = @in_macro
      @in_macro = true
      begin
        yield
      ensure
        @in_macro = old_value
      end
    end
  end
end
