require "./variabling/*"

module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  class Scope
    # Whether the scope yields.
    setter yields = false

    # Scope visibility level
    setter visibility : Crystal::Visibility?

    # Link to local variables
    getter variables = [] of Variable

    # Link to all variable references in currency scope
    getter references = [] of Reference

    # Link to the arguments in current scope
    getter arguments = [] of Argument

    # Link to the instance variables used in current scope
    getter ivariables = [] of InstanceVariable

    # Link to the type declaration variables used in current scope
    getter type_dec_variables = [] of TypeDecVariable

    # Link to the outer scope
    getter outer_scope : Scope?

    # List of inner scopes
    getter inner_scopes = [] of Scope

    # The actual AST node that represents a current scope.
    getter node : Crystal::ASTNode

    delegate to_s, to: node
    delegate location, to: node
    delegate end_location, to: node

    def_equals_and_hash node, location

    # Creates a new scope. Accepts the AST node and the outer scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # ```
    def initialize(@node, @outer_scope = nil)
      @outer_scope.try &.inner_scopes.<< self
    end

    # Creates a new variable in the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_variable(var_node)
    # ```
    def add_variable(node)
      variables << Variable.new(node, self)
    end

    # Creates a new argument in the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_argument(arg_node)
    # ```
    def add_argument(node)
      add_variable Crystal::Var.new(node.name).at(node)
      arguments << Argument.new(node, variables.last)
    end

    # Adds a new instance variable to the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_ivariable(ivar_node)
    # ```
    def add_ivariable(node)
      ivariables << InstanceVariable.new(node)
    end

    # Adds a new type declaration variable to the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_type_dec_variable(node)
    # ```
    def add_type_dec_variable(node)
      type_dec_variables << TypeDecVariable.new(node)
    end

    # Returns variable by its name or `nil` if it does not exist.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.find_variable("foo")
    # ```
    def find_variable(name : String)
      variables.find(&.name.==(name)) ||
        outer_scope.try &.find_variable(name)
    end

    # Creates a new assignment for the variable.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.assign_variable(var_name, assign_node)
    # ```
    def assign_variable(name, node)
      find_variable(name).try &.assign(node, self)
    end

    # Returns `true` if current scope represents a block (or proc),
    # `false` otherwise.
    def block?
      node.is_a?(Crystal::Block) ||
        node.is_a?(Crystal::ProcLiteral)
    end

    # Returns `true` if current scope represents a spawn block, e. g.
    #
    # ```
    # spawn do
    #   # ...
    # end
    # ```
    def spawn_block?
      node.as?(Crystal::Block).try(&.call).try(&.name) == "spawn"
    end

    # Returns `true` if current scope sits inside a macro.
    def in_macro?
      (node.is_a?(Crystal::Macro) ||
        node.is_a?(Crystal::MacroIf) ||
        node.is_a?(Crystal::MacroFor)) ||
        !!outer_scope.try(&.in_macro?)
    end

    # Returns `true` if instance variable is assigned in this scope.
    def assigns_ivar?(name)
      arguments.any?(&.name.== name) &&
        ivariables.any?(&.name.== "@#{name}")
    end

    # Returns `true` if type declaration variable is assigned in this scope.
    def assigns_type_dec?(name)
      type_dec_variables.any?(&.name.== name) ||
        !!outer_scope.try(&.assigns_type_dec?(name))
    end

    # Returns `true` if and only if current scope represents some
    # type definition, for example a class.
    def type_definition?
      node.is_a?(Crystal::ClassDef) ||
        node.is_a?(Crystal::ModuleDef) ||
        node.is_a?(Crystal::EnumDef) ||
        node.is_a?(Crystal::LibDef) ||
        node.is_a?(Crystal::FunDef) ||
        node.is_a?(Crystal::TypeDef) ||
        node.is_a?(Crystal::CStructOrUnionDef)
    end

    # Returns `true` if current scope (or any of inner scopes) references variable,
    # `false` otherwise.
    def references?(variable : Variable, check_inner_scopes = true)
      variable.references.any? do |reference|
        (reference.scope == self) ||
          (check_inner_scopes && inner_scopes.any?(&.references?(variable)))
      end || variable.used_in_macro?
    end

    # Returns `true` if current scope (or any of inner scopes) yields,
    # `false` otherwise.
    def yields?(check_inner_scopes = true)
      @yields || (check_inner_scopes && inner_scopes.any?(&.yields?))
    end

    # Returns visibility of the current scope (could be inherited from the outer scope).
    def visibility
      @visibility || outer_scope.try(&.visibility)
    end

    # Returns `true` if current scope is a def, `false` otherwise.
    def def?
      node.is_a?(Crystal::Def)
    end

    # Returns `true` if current scope is a class, `false` otherwise.
    def class_def?
      node.is_a?(Crystal::ClassDef)
    end

    # Returns `true` if current scope is a module, `false` otherwise.
    def module_def?
      node.is_a?(Crystal::ModuleDef)
    end

    # Returns `true` if this scope is a top level scope, `false` otherwise.
    def top_level?
      outer_scope.nil? || type_definition?
    end

    # Returns `true` if var is an argument in current scope, `false` otherwise.
    def arg?(var)
      case current_node = node
      when Crystal::Def
        var.is_a?(Crystal::Arg) && any_arg?(current_node.args, var)
      when Crystal::Block
        var.is_a?(Crystal::Var) && any_arg?(current_node.args, var)
      when Crystal::ProcLiteral
        var.is_a?(Crystal::Var) && any_arg?(current_node.def.args, var)
      else
        false
      end
    end

    private def any_arg?(args, var)
      args.any? { |arg| arg.name == var.name && arg.location == var.location }
    end

    # Returns `true` if the *node* represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node == @node &&
        node.location &&
        node.location == @node.location
    end
  end
end
