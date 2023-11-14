module Ameba::Rule::Naming
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
  # Naming/VariableNames:
  #   Enabled: true
  # ```
  class VariableNames < Base
    properties do
      description "Enforces variable names to be in underscored case"
    end

    MSG = "Var name should be underscore-cased: %s, not %s"

    def test(source : Source)
      VarVisitor.new self, source
    end

    def test(source, node : Crystal::Var | Crystal::InstanceVar | Crystal::ClassVar)
      name = node.name.to_s

      return if (expected = name.underscore) == name

      issue_for node, MSG % {expected, name}
    end

    private class VarVisitor < AST::NodeVisitor
      private getter var_locations = [] of Crystal::Location

      def visit(node : Crystal::Var)
        !node.location.in?(var_locations) && super
      end

      def visit(node : Crystal::InstanceVar | Crystal::ClassVar)
        if location = node.location
          var_locations << location
        end
        super
      end
    end
  end
end
