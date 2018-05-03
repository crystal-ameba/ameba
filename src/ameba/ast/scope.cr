require "./variabling/*"

module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  class Scope
    # Link to local variables
    getter variables = [] of Variable

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
    # scope.assign_variable(var_node)
    # ```
    def assign_variable(node)
      node.is_a?(Crystal::Var) && find_variable(node.name).try &.assign(node)
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

    # Returns true if current scope references variable, false if not.
    def references?(variable : Variable)
      variable.references.any? { |reference| reference.scope == self }
    end

    # Returns arguments of this scope (if any).
    def args
      case current_node = node
      when Crystal::Block, Crystal::Def then current_node.args
      when Crystal::ProcLiteral         then current_node.def.args
      else
        [] of Crystal::Var
      end
    end

    # Returns true if variable is an argument in current scope, false if not.
    def arg?(var : Crystal::Var)
      args.any? do |arg|
        arg.is_a?(Crystal::Var) &&
          arg.name == var.name &&
          arg.location == var.location
      end
    end

    # Returns true if the `node` represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node == @node && node.location == @node.location
    end
  end
end
