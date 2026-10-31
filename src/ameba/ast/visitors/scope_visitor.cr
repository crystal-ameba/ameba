require "./base_visitor"

module Ameba::AST
  # AST Visitor that traverses the source and constructs scopes.
  class ScopeVisitor < BaseVisitor
    include Util
    include ScopeBuilding

    # Non-exhaustive list of nodes to be visited by Ameba's rules.
    NODES = {
      ClassDef,
      ModuleDef,
      EnumDef,
      LibDef,
      FunDef,
      TypeDef,
      TypeOf,
      CStructOrUnionDef,
      ProcLiteral,
      Block,
      Macro,
      MacroIf,
      MacroFor,
    }

    SPECIAL_NODE_NAMES = %w[super previous_def]

    @scope_queue = [] of Scope
    @current_visibility : Crystal::Visibility?
    @skip : Array(Crystal::ASTNode.class)?

    # Creates a new visitor, skipping the scopes of the *skip* node types,
    # and the field macros (`record` and accessor ones, i.e. `getter`).
    #
    # When *visit_field_macros* is `true`, the default values and blocks
    # of the field macros are visited, skipping only the field declarations.
    def initialize(@rule, @source, skip = nil, @visit_field_macros = false)
      @current_scope = Scope.new(@source.ast) # top level scope
      @skip = skip.try(&.map(&.as(Crystal::ASTNode.class)))

      super @rule, @source

      if @scope_queue.empty?
        @rule.test(@source, @current_scope.node, @current_scope)
      else
        @scope_queue.each do |scope|
          @rule.test(@source, scope.node, scope)
        end
      end
    end

    private def on_scope_enter(node)
      return if skip?(node)

      scope = Scope.new(node, @current_scope)
      scope.visibility = @current_visibility

      @current_scope = scope
      true
    end

    private def on_scope_end(node)
      @scope_queue << @current_scope

      @current_visibility = nil

      # go up if this is not a top level scope
      if outer_scope = @current_scope.outer_scope
        @current_scope = outer_scope
      end
    end

    {% for name in NODES %}
      # :nodoc:
      def visit(node : Crystal::{{ name }})
        on_scope_enter(node)
      end
    {% end %}

    # :nodoc:
    def visit(node : Crystal::VisibilityModifier)
      @current_visibility = node.exp.visibility = node.modifier
      true
    end

    # :nodoc:
    def visit(node : Crystal::Yield)
      @current_scope.yields = true
      true
    end

    # :nodoc:
    def visit(node : Crystal::Assign | Crystal::OpAssign)
      target = node.target

      if isolated_assign_target?(target)
        target.accept(self)
        visit_isolated_value(node, node.value)
        return false
      end

      super
    end

    # :nodoc:
    def visit(node : Crystal::TypeDeclaration)
      value, var = node.value, node.var

      if value && isolated_assign_target?(var)
        var.accept(self)
        visit_isolated_value(node, value)
        return false
      end

      super
    end

    # :nodoc:
    def visit(node : Crystal::Call)
      scope = @current_scope
      case
      when (scope.top_level? || scope.type_definition?) && record_macro?(node),
           scope.type_definition? && accessor_macro?(node)
        if @visit_field_macros
          node.args.each { |arg| visit_field_value(arg) }
          node.block.try(&.accept(self))
        end
        return false
      when special_node?(node) && (def_scope = special_node_def_scope(scope))
        def_scope.arguments.each do |arg|
          ref = arg.variable.reference(scope)
          ref.explicit = false
        end
      end
      true
    end

    # Visits the default value of the field declaration *node* (if any)
    # within an isolated scope, i.e. `bar` in `getter foo = bar`.
    private def visit_field_value(node)
      case node
      when Crystal::Assign, Crystal::TypeDeclaration
        node.value.try { |value| visit_isolated_value(node, value) }
      end
    end

    # Visits the *value* assigned by the *node* within an isolated scope,
    # since it's not evaluated within the current one, i.e. `bar` in
    # `@foo = bar` within a type definition, evaluated by the initializers.
    private def visit_isolated_value(node, value) : Nil
      @current_assign = node

      on_scope_enter(node)
      value.accept(self)
      on_scope_end(node) if @current_scope.eql?(node)

      @current_assign = nil
    end

    # Returns `true` if the *node* implicitly forwards the arguments
    # of the enclosing method, i.e. `super`, but not `super()`.
    private def special_node?(node)
      node.name.in?(SPECIAL_NODE_NAMES) &&
        node.args.empty? && !node.has_parentheses?
    end

    # Returns the scope of the method whose arguments are forwarded by
    # the special node within *scope*, looking through any enclosing
    # blocks (or procs), or `nil` if it's not within a method.
    private def special_node_def_scope(scope) : Scope?
      while scope && scope.block?
        scope = scope.outer_scope
      end
      scope if scope.try(&.def?)
    end

    private def accessor_macro?(node)
      node.name.matches?(/^(class_)?(getter[?!]?|setter|property[?!]?)$/)
    end

    private def record_macro?(node)
      return false unless node.name == "record"

      case node.args.first?
      when Crystal::Path, Crystal::Generic
        true
      else
        false
      end
    end

    private def isolated_assign_target?(target)
      case target
      when Crystal::Path
        true
      when Crystal::InstanceVar, Crystal::ClassVar
        @current_scope.type_definition?
      else
        false
      end
    end

    private def skip?(node)
      !!@skip.try(&.includes?(node.class))
    end
  end
end
