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

        # TODO: The liveness analysis doesn't descend into inner scopes
        #       (i.e. blocks), so the variables referenced within any of them
        #       are skipped, which hides i.e. the variable overwritten before
        #       being referenced within a block, as in
        #       `rescue ex; end; ex = nil; [1].each { puts ex }`.
        #       Once the analysis treats the inner scope references as reads
        #       at their location, this can be narrowed down to the inner
        #       scopes preceding the `rescue`, which might be invoked later.
        next if var.captured_by_block?
        next if scope.inner_scopes.any?(&.references?(var))
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
