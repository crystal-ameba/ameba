module Ameba::Rule::Lint
  # Checks that there are no repeated bodies within `if/unless`,
  # `case-when`, `case-in` and `rescue` constructs.
  #
  # This is considered invalid:
  #
  # ```
  # if foo
  #   do_foo
  #   do_something_else
  # elsif bar
  #   do_foo
  #   do_something_else
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # if foo || bar
  #   do_foo
  #   do_something_else
  # end
  # ```
  #
  # With `IgnoreLiteralBranches: true`, branches are not registered
  # as offenses if they return a basic literal value (string, symbol,
  # integer, float, `true`, `false`, or `nil`), or return an array,
  # hash, regexp or range that only contains one of the above basic
  # literal values.
  #
  # With `IgnoreConstantBranches: true`, branches are not registered
  # as offenses if they return a constant value.
  #
  # With `IgnoreDuplicateElseBranch: true`, in conditionals with multiple branches,
  # duplicate 'else' branches are not registered as offenses.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DuplicateBranch:
  #   Enabled: true
  #   IgnoreLiteralBranches: false
  #   IgnoreConstantBranches: false
  #   IgnoreDuplicateElseBranch: false
  # ```
  class DuplicateBranch < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Reports duplicated branch bodies"
      enabled false

      ignore_literal_branches false
      ignore_constant_branches false
      ignore_duplicate_else_branch false
    end

    MSG = "Duplicate branch body detected"

    def test(source)
      AST::ElseIfAwareNodeVisitor.new self, source, skip: :macro
    end

    def test(
      source,
      node : Crystal::If | Crystal::Unless | Crystal::Case | Crystal::ExceptionHandler,
      ifs : Enumerable(Crystal::If)? = nil,
    )
      found_bodies = Set(String).new

      each_branch(ifs || node) do |body_node|
        next if ignore_literal_branches? && static_literal?(body_node)
        next if ignore_constant_branches? && body_node.is_a?(Crystal::Path)
        next if found_bodies.add?(body_node.to_s)

        issue_for body_node, MSG
      end
    end

    private def each_branch(ifs : Enumerable(Crystal::If), &)
      ifs.each do |if_node|
        yield if_node.then
      end
      if !ignore_duplicate_else_branch? && (else_node = ifs.last.else)
        yield else_node
      end
    end

    private def each_branch(node : Crystal::If | Crystal::Unless, &)
      if !ignore_duplicate_else_branch? && (else_node = node.else)
        yield node.then
        yield else_node
      end
    end

    private def each_branch(node : Crystal::Case, &)
      node.whens.each do |when_node|
        yield when_node.body
      end
      if !ignore_duplicate_else_branch? && (else_node = node.else)
        yield else_node
      end
    end

    private def each_branch(node : Crystal::ExceptionHandler, &)
      node.rescues.try &.each do |rescue_node|
        yield rescue_node.body
      end
      if !ignore_duplicate_else_branch? && (else_node = node.else)
        yield else_node
      end
    end
  end
end
