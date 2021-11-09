module Ameba::Rule::Style
  # A rule that enforces variable names to be in underscored case.
  #
  # For example, these variable names are considered valid:
  #
  # ```
  # var_name = 1
  # name = 2
  # _another_good_name = 3
  # ```
  #
  # And these are invalid variable names:
  #
  # ```
  # myBadNamedVar = 1
  # wrong_Name = 2
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/VariableNames:
  #   Enabled: true
  # ```
  class VariableNames < Base
    properties do
      description "Enforces variable names to be in underscored case"
    end

    MSG = "Var name should be underscore-cased: %s, not %s"

    private def check_node(source, node)
      return if (expected = node.name.underscore) == node.name

      issue_for node, MSG % {expected, node.name}
    end

    def test(source : Source)
      VarVisitor.new self, source
    end

    def test(source, node : Crystal::Var)
      check_node source, node
    end

    def test(source, node : Crystal::InstanceVar)
      check_node source, node
    end

    def test(source, node : Crystal::ClassVar)
      check_node source, node
    end

    private class VarVisitor < AST::NodeVisitor
      private getter var_locations = [] of Crystal::Location

      def visit(node : Crystal::Var)
        !var_locations.includes?(node.location) && super
      end

      def visit(node : Crystal::InstanceVar | Crystal::ClassVar)
        if (location = node.location)
          var_locations << location
        end
        super
      end
    end
  end
end
