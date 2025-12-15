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
  # YAML configuration example:
  #
  # ```
  # Style/Elsif:
  #   Enabled: true
  #   MaxBranches: 0
  # ```
  class Elsif < Base
    properties do
      since_version "1.7.0"
      description "Encourages the use of `case/when` syntax over `if/elsif`"
      enabled false
      max_branches 0
    end

    MSG = "Prefer `case/when` over `if/elsif`"

    def test(source)
      AST::ElseIfAwareNodeVisitor.new self, source, skip: :macro
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
