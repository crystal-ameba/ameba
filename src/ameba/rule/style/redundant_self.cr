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
      AST::ScopeCallsWithSelfReceiverVisitor.new self, source
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

      vars = Set(String).new

      while scope
        break if scope.type_definition?

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
      return unless node_source = node_source(node, source.lines)

      issue_for obj, MSG do |corrector|
        corrector.replace(node, node_source.sub(/\Aself\s*\./, ""))
      end
    end
  end
end
