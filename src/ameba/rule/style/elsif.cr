module Ameba::Rule::Style
  # A rule that encourages the use of `case/when` syntax over `if/elsif`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # if foo
  #   do_something_foo
  # elsif bar
  #   do_something_bar
  # end
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # case
  # when foo
  #   do_something_foo
  # when bar
  #   do_something_bar
  # end
  # ```
  #
  # If `IgnoreSuffix` option is set to `true` (which is the default),
  # the suffix `if` nodes will be ignored, i.e., considered valid.
  #
  # ```
  # if foo
  #   do_something
  # else
  #   do_something_else if bar # <- suffix if node
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/Elsif:
  #   Enabled: true
  #   IgnoreSuffix: true
  #   MaxBranches: 0
  # ```
  class Elsif < Base
    properties do
      since_version "1.7.0"
      description "Encourages the use of `case/when` syntax over `if/elsif`"
      enabled false
      ignore_suffix true
      max_branches 0
    end

    MSG = "Prefer `case/when` over `if/elsif`"

    def test(source)
      AST::ElseIfAwareNodeVisitor.new self, source, skip: :macro,
        exclude_suffix: ignore_suffix?
    end

    def test(source, node : Crystal::If, ifs : Enumerable(Crystal::If))
      return if valid_branches_amount?(ifs)
      issue_for node, MSG
    end

    private def valid_branches_amount?(ifs)
      # 1st item is always the `if` branch
      ifs.size - 1 <= max_branches
    end
  end
end
