module Ameba::AST
  # Shared logic of the visitors constructing scopes: tracking variables,
  # their assignments and references within the current scope.
  #
  # Including types need to implement `on_scope_enter` and `on_scope_end`
  # methods, and to initialize the top level `@current_scope`.
  module ScopeBuilding
    @current_scope : Scope
    @current_assign : Crystal::ASTNode?

    private abstract def on_scope_enter(node)
    private abstract def on_scope_end(node)

    private def on_assign_end(target, node)
      if var = Util.assigned_var(target)
        @current_scope.assign_variable(var.name, node)
      end
    end

    # A main visit method that accepts `Crystal::ASTNode`.
    # Returns `true`, meaning all child nodes will be traversed.
    #
    # NOTE: Needs to be defined here, since the more specific overloads below
    #       would be shadowed by the one defined in the including type.
    def visit(node : Crystal::ASTNode)
      true
    end

    # :nodoc:
    #
    # NOTE: The more specific `end_visit` overloads below need to do the same,
    #       since the node might be the top level scope one (i.e. a single
    #       expression file).
    def end_visit(node : Crystal::ASTNode)
      on_scope_end(node) if @current_scope.eql?(node)
    end

    # :nodoc:
    def visit(node : Crystal::Def)
      node.name == "->" || on_scope_enter(node)
    end

    # :nodoc:
    def visit(node : Crystal::Assign | Crystal::OpAssign)
      @current_assign = node
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::Assign | Crystal::OpAssign)
      on_assign_end(node.target, node)
      @current_assign = nil
    end

    # :nodoc:
    def visit(node : Crystal::MultiAssign | Crystal::UninitializedVar)
      @current_assign = node
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::MultiAssign)
      node.targets.each { |target| on_assign_end(target, node) }
      @current_assign = nil

      on_scope_end(node) if @current_scope.eql?(node)
    end

    # :nodoc:
    def end_visit(node : Crystal::UninitializedVar)
      on_assign_end(node.var, node)
      @current_assign = nil

      on_scope_end(node) if @current_scope.eql?(node)
    end

    # :nodoc:
    def visit(node : Crystal::TypeDeclaration)
      return unless (var = node.var).is_a?(Crystal::Var)

      @current_scope.add_variable(var)
      @current_scope.add_type_dec_variable(node)

      @current_assign = node.value if node.value
      true
    end

    # :nodoc:
    def end_visit(node : Crystal::TypeDeclaration)
      if (var = node.var).is_a?(Crystal::Var)
        on_assign_end(var, node)
        @current_assign = nil
      end

      on_scope_end(node) if @current_scope.eql?(node)
    end

    # :nodoc:
    def visit(node : Crystal::InstanceVar)
      @current_scope.add_ivariable(node)
      true
    end

    # :nodoc:
    def visit(node : Crystal::Var)
      scope = @current_scope
      variable = scope.find_variable(node.name)

      case
      when scope.arg?(node)
        # node is an argument, already registered by the scope
      when variable.nil? && @current_assign # node is a variable
        scope.add_variable(node)
      when variable # node is a reference
        variable.reference(node, scope)
      end
      true
    end

    # :nodoc:
    def visit(node : Crystal::Rescue)
      @current_scope.add_rescue_variable(node)
      true
    end

    # :nodoc:
    def visit(node : Crystal::Out)
      # `out x` declares (or assigns) the variable, rather than reading it
      !@current_scope.add_out_variable(node)
    end

    # :nodoc:
    def visit(node : Crystal::PointerOf)
      return true unless (var = node.exp).is_a?(Crystal::Var)
      return true unless variable = @current_scope.find_variable(var.name)

      variable.reference(var, @current_scope).address_taken = true
      false
    end
  end
end
