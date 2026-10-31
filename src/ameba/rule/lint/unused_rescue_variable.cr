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
      AST::ScopeVisitor.new(self, source, visit_macro_blocks: true)
    end

    def test(source, node, scope : AST::Scope)
      captured_variables, shadowed_variables = outer_rescue_variables(scope)
      return unless captured_variables.present? || shadowed_variables.present? ||
                    scope.variables.any? { |var| rescue_assigned?(var, scope) }

      analyzer = AST::LivenessAnalyzer.new(scope, captured_variables, shadowed_variables)
      analyzer.dead_stores.each do |assign|
        next unless (rescue_node = assign.node).is_a?(Crystal::Rescue)

        next if assign.referenced_in_preceding_inner_scope?
        next if assign.address_taken_before?

        issue_for(name_location_or(rescue_node), MSG % assign.variable.name)
      end
    end

    # Returns the outer scope variables assigned by the `rescue` nodes
    # of the *scope*, split into the ones captured by the *scope*
    # (i.e. a block), and the ones shadowed by it, being beyond
    # a type definition, which doesn't see the outer scope variables.
    private def outer_rescue_variables(scope)
      captured_variables = [] of AST::Variable
      shadowed_variables = [] of AST::Variable

      shadowed = false
      current_scope = scope
      while current_scope.inherited? && (outer_scope = current_scope.outer_scope)
        shadowed ||= current_scope.type_definition?

        variables = outer_scope.variables.select { |var| rescue_assigned?(var, scope) }
        (shadowed ? shadowed_variables : captured_variables).concat(variables)

        current_scope = outer_scope
      end
      {captured_variables, shadowed_variables}
    end

    private def rescue_assigned?(var, scope)
      var.assignments.any? do |assign|
        assign.scope.same?(scope) && assign.node.is_a?(Crystal::Rescue)
      end
    end
  end
end
