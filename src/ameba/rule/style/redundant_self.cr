require "compiler/crystal/syntax/token"

module Ameba::Rule::Style
  # A rule that disallows redundant uses of `self`.
  #
  # This is considered bad:
  #
  # ```
  # class Greeter
  #   getter name : String
  #
  #   def self.init
  #     self.new("Crystal").greet
  #   end
  #
  #   def initialize(@name)
  #   end
  #
  #   def greet
  #     puts "Hello, my name is #{self.name}"
  #   end
  #
  #   self.init
  # end
  # ```
  #
  # And needs to be written as:
  #
  # ```
  # class Greeter
  #   getter name : String
  #
  #   def self.init
  #     new("Crystal").greet
  #   end
  #
  #   def initialize(@name)
  #   end
  #
  #   def greet
  #     puts "Hello, my name is #{name}"
  #   end
  #
  #   init
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/RedundantSelf:
  #   Enabled: true
  #   AllowedMethodNames:
  #     - in?
  #     - inspect
  #     - not_nil!
  # ```
  class RedundantSelf < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows redundant uses of `self`"

      allowed_method_names %w[in? inspect not_nil!]
    end

    MSG = "Redundant `self` detected"

    CRYSTAL_KEYWORDS = Crystal::Keyword.values.map(&.to_s)

    def test(source)
      ScopeCallsWithSelfReceiverVisitor.new self, source
    end

    def test(source, node : Crystal::Call, scope : AST::Scope)
      return unless (obj = node.obj).is_a?(Crystal::Var)

      name = node.name

      return if name.in?(CRYSTAL_KEYWORDS)
      return if name.in?(allowed_method_names)
      return if name.ends_with?('=')
      return if name.chars.none?(&.alphanumeric?)

      vars = Set(String).new

      while scope
        scope.arguments.each do |arg|
          vars << arg.name
        end
        scope.variables.each do |var|
          var.assignments.each do |assign|
            vars << assign.variable.name
          end
        end
        scope = scope.outer_scope
      end

      return if name.in?(vars)

      if location = obj.location
        issue_for obj, MSG do |corrector|
          corrector.remove(location, location.adjust(column_number: {{ "self".size }}))
        end
      else
        issue_for obj, MSG
      end
    end

    private class ScopeCallsWithSelfReceiverVisitor < Crystal::Visitor
      @current_scope : AST::Scope
      @current_assign : Crystal::ASTNode?

      @scope_call_queue = {} of AST::Scope => Array(Crystal::Call)

      def initialize(rule, source)
        @current_scope = AST::Scope.new(source.ast) # top level scope

        source.ast.accept self

        @scope_call_queue.each do |scope, calls|
          calls.each do |call|
            rule.test source, call, scope
          end
        end
      end

      private def on_scope_enter(node)
        scope = AST::Scope.new(node, @current_scope)

        @current_scope = scope
      end

      private def on_scope_end(node)
        # go up if this is not a top level scope
        if outer_scope = @current_scope.outer_scope
          @current_scope = outer_scope
        end
      end

      private def on_assign_end(target, node)
        target.is_a?(Crystal::Var) &&
          @current_scope.assign_variable(target.name, node)
      end

      # A main visit method that accepts `Crystal::ASTNode`.
      # Returns `true`, meaning all child nodes will be traversed.
      def visit(node : Crystal::ASTNode)
        true
      end

      def end_visit(node : Crystal::ASTNode)
        on_scope_end(node) if @current_scope.eql?(node)
      end

      def visit(node : Crystal::Def)
        node.name == "->" || on_scope_enter(node)
      end

      def visit(node : Crystal::Block | Crystal::ProcLiteral)
        on_scope_enter(node)
      end

      def visit(node : Crystal::ClassDef | Crystal::ModuleDef)
        on_scope_enter(node)
      end

      def visit(node : Crystal::Assign | Crystal::OpAssign | Crystal::MultiAssign | Crystal::UninitializedVar)
        @current_assign = node
      end

      def end_visit(node : Crystal::Assign | Crystal::OpAssign)
        on_assign_end(node.target, node)
        @current_assign = nil
      end

      def end_visit(node : Crystal::MultiAssign)
        node.targets.each { |target| on_assign_end(target, node) }
        @current_assign = nil
      end

      def end_visit(node : Crystal::UninitializedVar)
        on_assign_end(node.var, node)
        @current_assign = nil
      end

      def visit(node : Crystal::TypeDeclaration)
        return unless (var = node.var).is_a?(Crystal::Var)

        @current_scope.add_variable(var)
        @current_scope.add_type_dec_variable(node)

        @current_assign = node.value if node.value
      end

      def end_visit(node : Crystal::TypeDeclaration)
        return unless (var = node.var).is_a?(Crystal::Var)

        on_assign_end(var, node)
        @current_assign = nil
      end

      def visit(node : Crystal::Arg)
        @current_scope.add_argument(node)
      end

      def visit(node : Crystal::InstanceVar)
        @current_scope.add_ivariable(node)
      end

      def visit(node : Crystal::Var)
        scope = @current_scope
        variable = scope.find_variable(node.name)

        case
        when scope.arg?(node) # node is an argument
          scope.add_argument(node)
        when variable.nil? && @current_assign # node is a variable
          scope.add_variable(node)
        when variable # node is a reference
          reference = variable.reference(node, scope)
          if @current_assign.is_a?(Crystal::OpAssign) || !reference.target_of?(@current_assign)
            variable.reference_assignments!
          end
        end
      end

      def visit(node : Crystal::Call)
        if (obj = node.obj).is_a?(Crystal::Var) && obj.name == "self"
          calls = @scope_call_queue[@current_scope] ||= [] of Crystal::Call
          calls << node
        end

        true
      end
    end
  end
end
