require "./variabling/*"

module Ameba::AST
  # Represents a context of the local variable visibility.
  # This is where the local variables belong to.
  class Scope
    include Util

    # Whether the scope yields.
    setter yields = false

    # Scope visibility level
    setter visibility : Crystal::Visibility?

    # Link to local variables
    getter variables = [] of Variable

    # Link to all variable references in current scope
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

    delegate location, end_location, to_s,
      to: @node

    def_equals_and_hash node, location

    # Creates a new scope. Accepts the AST node and the outer scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # ```
    def initialize(@node, @outer_scope = nil)
      @outer_scope.try(&.inner_scopes.<< self)

      # Some arguments (i.e. unpacked block arguments, or macro's double splat
      # and block arguments) are visited after the body, so they need to be
      # registered before they're referenced
      add_arguments(node)
    end

    private def add_arguments(node : Crystal::Def | Crystal::Macro)
      node.args.each { |arg| add_argument(arg) }
      node.double_splat.try { |arg| add_argument(arg) }
      node.block_arg.try { |arg| add_argument(arg) }
    end

    private def add_arguments(node : Crystal::FunDef)
      node.args.each { |arg| add_argument(arg) }
    end

    private def add_arguments(node : Crystal::ProcLiteral)
      add_arguments(node.def)
    end

    private def add_arguments(node : Crystal::Block)
      all_block_args(node).each { |arg| add_argument(arg) }
    end

    private def add_arguments(node : Crystal::ASTNode)
    end

    # Creates a new variable in the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_variable(var_node)
    # ```
    def add_variable(node) : Variable
      Variable.new(node, self).tap do |var|
        variables << var
      end
    end

    # Declares the variable of the `rescue` *node* (i.e. `ex` in `rescue ex`)
    # and assigns it. Just like with an assignment, the already visible
    # variable with the same name gets reassigned instead.
    #
    # ```
    # scope = Scope.new(def_node, nil)
    # scope.add_rescue_variable(rescue_node)
    # ```
    def add_rescue_variable(node : Crystal::Rescue) : Variable?
      return unless name = node.name

      declare_variable(Crystal::Var.new(name).at(node.name_location), node)
    end

    # Declares the variable of the `out` *node* (i.e. `x` in `foo(out x)`)
    # and assigns it. Just like with an assignment, the already visible
    # variable with the same name gets reassigned instead.
    #
    # ```
    # scope = Scope.new(def_node, nil)
    # scope.add_out_variable(out_node)
    # ```
    def add_out_variable(node : Crystal::Out) : Variable?
      return unless (var = node.exp).is_a?(Crystal::Var)

      declare_variable(var, node)
    end

    # Declares the *var*, unless the variable with the same name is already
    # visible, and assigns it using the given assignment *node*.
    private def declare_variable(var : Crystal::Var, node) : Variable
      variable = find_variable(var.name) || add_variable(var)
      variable.tap(&.assign(node, self))
    end

    # Creates a new argument in the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_argument(arg_node)
    # ```
    def add_argument(node) : Argument
      var = add_variable(Crystal::Var.new(node.name).at(node))
      Argument.new(node, var).tap do |arg|
        arguments << arg
      end
    end

    # Adds a new instance variable to the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_ivariable(ivar_node)
    # ```
    def add_ivariable(node) : InstanceVariable
      InstanceVariable.new(node).tap do |ivar|
        ivariables << ivar
      end
    end

    # Adds a new type declaration variable to the current scope.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.add_type_dec_variable(node)
    # ```
    def add_type_dec_variable(node) : TypeDecVariable
      TypeDecVariable.new(node).tap do |type_dec_var|
        type_dec_variables << type_dec_var
      end
    end

    # Returns variable by its name or `nil` if it does not exist.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.find_variable("foo")
    # ```
    def find_variable(name : String)
      variables.find(&.name.==(name)) ||
        inherited? { outer_scope.try(&.find_variable(name)) }
    end

    # Creates a new assignment for the variable.
    #
    # ```
    # scope = Scope.new(class_node, nil)
    # scope.assign_variable(var_name, assign_node)
    # ```
    def assign_variable(name, node)
      find_variable(name).try(&.assign(node, self))
    end

    # Returns `true` if a local variable named *name* has a definition that
    # reaches the program point where *node* (an inner scope's node) is
    # introduced.
    #
    # ```
    # scope.declared_at?("foo", block_node)
    # ```
    def declared_at?(name : String, node) : Bool
      !!reaching_definitions[node.object_id]?.try(&.includes?(name))
    end

    # Reaching definitions snapshotted at each inner scope's node. Computed
    # lazily and memoized, since several inner scopes share the same outer one.
    protected getter reaching_definitions : Hash(UInt64, Set(String)) do
      ReachingDefinitionAnalyzer.new(self, entry_definitions).inner_scope_definitions
    end

    # The set of variable names already defined when this scope is entered:
    # its own arguments plus any captured definitions from the outer scope.
    protected def entry_definitions : Set(String)
      defined = arguments.to_set(&.name)

      if inherited? && (outer = outer_scope)
        outer.reaching_definitions[node.object_id]?.try do |defs|
          defined.concat(defs)
        end
      end

      defined
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
    def assigns_type_dec_variable?(name)
      type_dec_variables.any?(&.name.== name) ||
        !!inherited? { outer_scope.try(&.assigns_type_dec_variable?(name)) }
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
          (check_inner_scopes && reference.scope.nested_in?(self))
      end || variable.used_in_macro?
    end

    # Returns `true` if current scope is nested (at any depth) within
    # the given *scope*, `false` otherwise.
    def nested_in?(scope : Scope) : Bool
      current_scope = outer_scope
      while current_scope
        return true if current_scope == scope
        current_scope = current_scope.outer_scope
      end
      false
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

    {% for type in %w[Def ClassDef ModuleDef EnumDef LibDef FunDef].map(&.id) %}
      {% method_name = type.underscore %}
      # Returns `true` if current scope is a {{ method_name[0..-5] }} def, `false` otherwise.
      def {{ method_name }}?(*, check_outer_scopes = false)
        node.is_a?(Crystal::{{ type }}) ||
          !!(check_outer_scopes &&
            outer_scope.try(&.{{ method_name }}?(check_outer_scopes: true)))
      end
    {% end %}

    # Returns `true` if this scope is a top level scope, `false` otherwise.
    def top_level?
      outer_scope.nil?
    end

    def inherited?
      !(node.is_a?(Crystal::Def) ||
        node.is_a?(Crystal::FunDef) ||
        node.is_a?(Crystal::Assign) ||
        node.is_a?(Crystal::OpAssign))
    end

    def inherited?(&)
      yield if inherited?
    end

    # Returns `true` if var is an argument in current scope, `false` otherwise.
    def arg?(var)
      arguments.any?(&.node.same?(var))
    end

    # Returns `true` if the *node* represents exactly
    # the same Crystal node as `@node`.
    def eql?(node)
      node == @node &&
        node.location == @node.location
    end
  end
end
