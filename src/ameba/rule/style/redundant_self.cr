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
  end
end
