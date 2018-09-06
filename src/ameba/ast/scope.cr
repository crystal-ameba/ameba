require "./variabling/*"

module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  class Scope
    # Link to local variables
    getter variables = [] of Variable

    # Link to the arguments in current scope
    getter arguments = [] of Argument

    # Link to the outer scope
    getter outer_scope : Scope?

    # List of inner scopes
    getter inner_scopes = [] of Scope

    # The actual AST node that represents a current scope.
    getter node : Crystal::ASTNode

    delegate to_s, to: node
    delegate location, to: node

    def_equals_and_hash node, location

    # Creates a new scope. Accepts the AST node and the outer scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # ```
    def initialize(@node, @outer_scope = nil)
      @outer_scope.try &.inner_scopes.<<(self)
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

    def add_argument(node)
      add_variable Crystal::Var.new(node.name).at(node.location)
      arguments << Argument.new(node, variables.last)
    end

    # Returns variable by its name or nil if it does not exist.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.find_variable("foo")
    # ```
    def find_variable(name : String)
      variables.find { |v| v.name == name } || outer_scope.try &.find_variable(name)
    end

    # Creates a new assignment for the variable.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.assign_variable(var_name, assign_node)
    # ```
    def assign_variable(name, node)
      find_variable(name).try &.assign(node)
    end

    # Returns true if current scope represents a block (or proc),
    # false if not.
    def block?
      node.is_a?(Crystal::Block) || node.is_a?(Crystal::ProcLiteral)
    end

    # Returns true if and only if current scope represents some
    # type definition, for example a class.
    def type_definition?
      node.is_a?(Crystal::ClassDef) ||
        node.is_a?(Crystal::ModuleDef) ||
        node.is_a?(Crystal::LibDef) ||
        node.is_a?(Crystal::FunDef) ||
        node.is_a?(Crystal::TypeDef) ||
        node.is_a?(Crystal::CStructOrUnionDef)
    end

    # Returns true if current scope (or any of inner scopes) references variable,
    # false if not.
    def references?(variable : Variable)
      variable.references.any? do |reference|
        reference.scope == self || inner_scopes.any?(&.references? variable)
      end
    end

    # Returns true if current scope is a def, false if not.
    def def?
      node.is_a? Crystal::Def
    end

    # Returns true if this scope is a top level scope, false if not.
    def top_level?
      outer_scope.nil?
    end

    # Returns true if var is an argument in current scope, false if not.
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

    # Returns true if the `node` represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node == @node &&
        !node.location.nil? &&
        node.location == @node.location
    end
  end
end
