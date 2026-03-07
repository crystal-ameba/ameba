module Ameba::Rule::Lint
  # A rule that disallows shadowed arguments.
  #
  # For example, this is considered invalid:
  #
  # ```
  # do_something do |foo|
  #   foo = 1 # shadows block argument
  #   foo
  # end
  #
  # def do_something(foo)
  #   foo = 1 # shadows method argument
  #   foo
  # end
  # ```
  #
  # and it should be written as follows:
  #
  # ```
  # do_something do |foo|
  #   foo = foo + 42
  #   foo
  # end
  #
  # def do_something(foo)
  #   foo = foo + 42
  #   foo
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ShadowedArgument:
  #   Enabled: true
  # ```
  class ShadowedArgument < Base
    properties do
      since_version "0.7.0"
      description "Disallows shadowed arguments"
    end

    MSG = "Argument `%s` is assigned before it is used"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node, scope : AST::Scope)
      return unless scope.def? || scope.block?

      args = scope.arguments.reject(&.ignored?)
      return if args.empty?

      result = AST::LivenessAnalyzer.new(scope).analyze
      dead_store_ids = nil

      args.each do |arg|
        next if result.entry_live_set.includes?(arg.name)
        next if arg.variable.captured_by_block?
        next if arg.variable.used_in_macro?
        next if scope.inner_scopes.any?(&.references?(arg.variable))

        assigns = arg.variable.assignments
        # Prefer the first non-dead-store assignment (the one whose value
        # actually gets used), falling back to the first assignment.
        dead_store_ids ||= result.dead_stores.map(&.node.object_id).to_set
        target = assigns.find { |a| !dead_store_ids.includes?(a.node.object_id) } || assigns.first?
        next unless target

        issue_for target.node, MSG % arg.name
      end
    end
  end
end
