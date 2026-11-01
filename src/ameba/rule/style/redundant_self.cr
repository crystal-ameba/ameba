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
  # NOTE: A block might be yielded with a different default receiver
  # (i.e. `with obj yield`), in which case removing `self` within it would
  # result in calling a method on that receiver instead. Set `AutocorrectInBlocks`
  # to `false` to report these without autocorrecting.
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
  #   AutocorrectInBlocks: true
  # ```
  class RedundantSelf < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows redundant uses of `self`"
      allowed_method_names %w[in? inspect not_nil!]
      autocorrect_in_blocks true
    end

    MSG = "Redundant `self` detected"

    private CRYSTAL_KEYWORDS      = Crystal::Keyword.values.map(&.to_s)
    private SELF_RECEIVER_PATTERN = /\Aself\s*\./

    def test(source)
      AST::ScopeCallsWithSelfReceiverVisitor.new(self, source)
    end

    def test(source, node : Crystal::Call, scope : AST::Scope)
      return if setter_method?(node) || operator_method?(node)

      # Guard against auto-expanded `OpAssign` nodes, i.e.
      # `self.a += b` is expanded to `self.a = self.a + b`.
      return unless node.location && node.end_location
      return unless (obj = node.obj).is_a?(Crystal::Var)

      name = node.name

      return if name.in?(CRYSTAL_KEYWORDS)
      return if name.in?(allowed_method_names)

      return if shadowed?(name, scope)
      return unless node_source = node_source(node, source.lines)

      if autocorrect?(node_source, scope)
        issue_for(obj, MSG) do |corrector|
          corrector.replace(node, node_source.sub(SELF_RECEIVER_PATTERN, ""))
        end
      else
        issue_for(obj, MSG)
      end
    end

    private def autocorrect?(node_source, scope)
      # Anything else between `self` and `.` (i.e. a comment) would need
      # to be removed along with it, so we don't autocorrect these.
      node_source.matches?(SELF_RECEIVER_PATTERN) &&
        (autocorrect_in_blocks? || !within_block?(scope))
    end

    # Returns `true` if calling the method *name* without a receiver
    # would refer to a local variable or a macro instead.
    private def shadowed?(name, scope)
      name.in?(visible_variable_names(scope)) ||
        name.in?(type_macro_names(scope))
    end

    # Returns `true` if the *scope* is (or is nested within) a block,
    # within the enclosing method or type definition.
    private def within_block?(scope)
      scope.each_scope_within_definition do |current|
        return true if current.node.is_a?(Crystal::Block)
      end
      false
    end

    # Returns names of the local variables (and arguments) visible
    # within the *scope*.
    private def visible_variable_names(scope)
      vars = Set(String).new
      outermost = scope

      scope.each_scope_within_definition do |current|
        current.arguments.each { |arg| vars << arg.name }
        current.variables.each { |var| vars << var.name }
        outermost = current
      end

      # Type definition bodies share their local variables with
      # the top-level scope, and so with each other.
      if outermost.top_level? || type_body?(outermost)
        add_type_body_variable_names(top_level_scope(outermost), vars)
      end

      vars
    end

    private def add_type_body_variable_names(scope, vars)
      scope.variables.each { |var| vars << var.name }
      scope.inner_scopes.each do |inner|
        add_type_body_variable_names(inner, vars) if type_body?(inner)
      end
    end

    # Returns names of the macros defined within (any of the definitions of)
    # the type enclosing the *scope*, which take precedence over the methods
    # with the same name when called without a receiver.
    private def type_macro_names(scope)
      names = Set(String).new

      while scope && !type_body?(scope)
        scope = scope.outer_scope
      end
      return names unless scope && (type_name = type_name(scope))

      each_type_body(top_level_scope(scope)) do |other|
        next unless type_name(other) == type_name
        next unless type = type_body(other)

        _, body = type
        exps = body.is_a?(Crystal::Expressions) ? body.expressions : {body}
        exps.each do |exp|
          names << exp.name if exp.is_a?(Crystal::Macro)
        end
      end

      names
    end

    private def each_type_body(scope, &block : AST::Scope ->)
      scope.inner_scopes.each do |inner|
        next unless type_body?(inner)

        block.call(inner)
        each_type_body(inner, &block)
      end
    end

    # Returns the full name of the type definition the *scope* represents,
    # resolved lexically against the enclosing type definitions.
    private def type_name(scope) : String?
      return unless type_body?(scope)

      names = [] of String
      while scope
        if type = type_body(scope)
          path, _ = type
          names = path.names + names
          break if path.global?
        end
        scope = scope.outer_scope
      end
      names.join("::")
    end

    private def type_body?(scope)
      !!type_body(scope)
    end

    # Returns the name and body of the type definition the *scope* represents.
    private def type_body(scope) : {Crystal::Path, Crystal::ASTNode}?
      case node = scope.node
      when Crystal::ClassDef  then {node.name, node.body}
      when Crystal::ModuleDef then {node.name, node.body}
      end
    end

    private def top_level_scope(scope)
      while outer = scope.outer_scope
        scope = outer
      end
      scope
    end
  end
end
