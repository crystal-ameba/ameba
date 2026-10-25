module Ameba::Rule::Lint
  # A rule that disallows unused `rescue` variables.
  #
  # For example, this is considered invalid:
  #
  # ```
  # begin
  #   raise MyException.new("OH NO!")
  # rescue ex : MyException
  #   puts "Rescued MyException"
  # end
  # ```
  #
  # and should be written as:
  #
  # ```
  # begin
  #   raise MyException.new("OH NO!")
  # rescue MyException
  #   puts "Rescued MyException"
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedRescueVariable:
  #   Enabled: true
  # ```
  class UnusedRescueVariable < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows unused `rescue` variables"
    end

    MSG = "Unused `rescue` variable `%s`"

    def test(source)
      AST::ScopeVisitor.new(self, source)
    end

    def test(source, node, scope : AST::Scope)
      return unless has_rescue_assignments?(scope)

      AST::LivenessAnalyzer.new(scope).dead_stores.each do |assign|
        next unless (rescue_node = assign.node).is_a?(Crystal::Rescue)

        var = assign.variable

        next if assign.referenced_in_preceding_inner_scope?
        next if AST::MacroReferenceFinder.new(rescue_node.body, var.name).references?

        issue_for(name_location_or(rescue_node), MSG % var.name)
      end
    end

    private def has_rescue_assignments?(scope)
      scope.variables.any? do |var|
        var.assignments.any?(&.node.is_a?(Crystal::Rescue))
      end
    end
  end
end
