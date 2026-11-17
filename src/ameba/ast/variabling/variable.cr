module Ameba::AST
  # Represents the existence of the local variable.
  # Holds the var node and variable assignments.
  class Variable
    # List of the assignments of this variable.
    getter assignments = [] of Assignment

    # List of the references of this variable.
    getter references = [] of Reference

    # The actual var node.
    getter node : Crystal::Var

    # Scope of this variable.
    getter scope : Scope

    delegate location, end_location, name, to_s,
      to: @node

    # Creates a new variable(in the scope).
    #
    # ```
    # Variable.new(node, scope)
    # ```
    def initialize(@node, @scope)
    end

    # Returns `true` if it is a special variable, i.e `$?`.
    def special?
      @node.special_var?
    end

    # Assigns the variable (creates a new assignment).
    # Variable may have multiple assignments.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.assign(node1)
    # variable.assign(node2)
    # variable.assignments.size # => 2
    # ```
    def assign(node, scope)
      assignments << Assignment.new(node, self, scope)
    end

    # Returns `true` if variable has any reference.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.reference(var_node, some_scope)
    # variable.referenced? # => true
    # ```
    def referenced?
      references.present?
    end

    # Creates a reference to this variable in some scope.
    #
    # ```
    # variable = Variable.new(node, scope)
    # variable.reference(var_node, some_scope)
    # ```
    def reference(node : Crystal::Var, scope : Scope)
      Reference.new(node, scope).tap do |reference|
        references << reference
        scope.references << reference
      end
    end

    # :ditto:
    def reference(scope : Scope)
      reference(node, scope)
    end

    # Returns `true` if the current var is referenced
    # in the block. For example this variable is captured
    # by block:
    #
    # ```
    # a = 1
    # 3.times { |i| a = a + i }
    # ```
    #
    # And this variable is not captured by block.
    #
    # ```
    # i = 1
    # 3.times { |i| i + 1 }
    # ```
    def captured_by_block?(scope = @scope)
      scope.inner_scopes.each do |inner_scope|
        return true if inner_scope.block? &&
                       inner_scope.references?(self, check_inner_scopes: false)
        return true if captured_by_block?(inner_scope)
      end

      false
    end

    # Returns `true` if current variable potentially referenced in a macro,
    # `false` if not.
    #
    # That is, in a macro code within the variable's scope (including
    # its inner scopes), or in any macro defined within the source, which
    # might be called (and expanded) within the variable's scope - either
    # directly, or i.e. via inheritance, module inclusion, or a receiver:
    #
    # ```
    # macro print_a
    #   puts a
    # end
    #
    # def foo
    #   a = 1 # used in macro
    #   print_a
    # end
    # ```
    #
    # NOTE: Macro code (`{{ ... }}`, `{% ... %}`) outside of the variable's
    # scope, but not within a macro definition, is expanded in place,
    # hence it can't reference the variable.
    def used_in_macro?(scope = @scope) : Bool
      return true if MacroReferenceFinder.new(scope.node, node.name).references?

      # The whole source has been searched already
      return false unless outer_scope = scope.outer_scope

      while outer_scope
        scope, outer_scope = outer_scope, outer_scope.outer_scope
      end

      MacroDefinitionsFinder.new(scope.node).macros.any? do |macro_node|
        MacroReferenceFinder.new(macro_node, node.name).references?
      end
    end

    # Collects the macro definitions (`macro foo ... end`), including
    # the macro code defining them (i.e. `{% for %} macro foo ... {% end %}`)
    private class MacroDefinitionsFinder < Crystal::Visitor
      # Matches a macro definition within the macro literal
      MACRO_DEFINITION = /(?<![\p{L}\p{N}_.:@$])macro\s+[\p{L}_]/

      getter macros = [] of Crystal::ASTNode

      def initialize(node)
        node.accept(self)
      end

      def visit(node : Crystal::Macro)
        @macros << node
        false
      end

      def visit(node : Crystal::MacroIf | Crystal::MacroFor | Crystal::MacroVerbatim)
        @macros << node if defines_macro?(node)
        false
      end

      # Macros can't be defined within methods
      def visit(node : Crystal::Def)
        false
      end

      def visit(node : Crystal::ASTNode)
        true
      end

      private def defines_macro?(node) : Bool
        MacroLiteralsMatcher.new(node, MACRO_DEFINITION).matches?
      end
    end

    # Matches the text of the macro literals within a node against a regex
    private class MacroLiteralsMatcher < Crystal::Visitor
      getter? matches = false

      def initialize(node, @regex : Regex)
        node.accept(self)
      end

      def visit(node : Crystal::MacroLiteral)
        !(@matches ||= node.value.matches?(@regex))
      end

      def visit(node : Crystal::ASTNode)
        !@matches
      end
    end

    # Returns `true` if the variable is a target (on the left) of the assignment,
    # `false` otherwise.
    def target_of?(assign)
      case assign
      when Crystal::UninitializedVar          then eql?(assign.var)
      when Crystal::Assign, Crystal::OpAssign then eql?(assign.target)
      when Crystal::MultiAssign
        assign.targets.any? { |target| eql?(Util.assigned_var(target)) }
      else
        false
      end
    end

    # Returns `true` if the name starts with '_', `false` if not.
    def ignored?
      name.starts_with?('_')
    end

    # Returns `true` if the `node` represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node.is_a?(Crystal::Var) &&
        node.name == @node.name &&
        node.location == @node.location
    end
  end
end
