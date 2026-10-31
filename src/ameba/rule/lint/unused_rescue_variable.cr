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
      AST::ScopeVisitor.new(self, source, visit_field_macros: true)
    end

    def test(source, node, scope : AST::Scope)
      captured_variables = captured_rescue_variables(scope)
      return unless captured_variables.present? ||
                    scope.variables.any? { |var| rescue_assigned?(var, scope) }

      analyzer = AST::LivenessAnalyzer.new(scope, captured_variables,
        conservative_rescue: false)
      analyzer.dead_stores.each do |assign|
        next unless (rescue_node = assign.node).is_a?(Crystal::Rescue)

        next if assign.referenced_in_preceding_inner_scope?
        next if assign.address_taken_before?

        issue_for(name_location_or(rescue_node), MSG % assign.variable.name)
      end
    end

    # Returns the outer scope variables captured by the *scope*
    # (i.e. a block), which are assigned by its `rescue` nodes.
    private def captured_rescue_variables(scope)
      variables = [] of AST::Variable

      current_scope = scope
      while current_scope.inherits_variables? && (outer_scope = current_scope.outer_scope)
        variables.concat(outer_scope.variables.select { |var| rescue_assigned?(var, scope) })
        current_scope = outer_scope
      end
      variables
    end

    private def rescue_assigned?(var, scope)
      var.assignments.any? do |assign|
        assign.scope.same?(scope) && assign.node.is_a?(Crystal::Rescue)
      end
    end
  end
end
