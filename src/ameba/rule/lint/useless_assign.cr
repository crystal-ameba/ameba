module Ameba::Rule::Lint
  # A rule that disallows useless assignments.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def method
  #   var = 1
  #   do_something
  # end
  # ```
  #
  # And has to be written as the following:
  #
  # ```
  # def method
  #   var = 1
  #   do_something(var)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UselessAssign:
  #   Enabled: true
  #   ExcludeTypeDeclarations: false
  # ```
  class UselessAssign < Base
    properties do
      description "Disallows useless variable assignments"
      exclude_type_declarations false
    end

    MSG = "Useless assignment to variable `%s`"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node, scope : AST::Scope)
      return if scope.lib_def?(check_outer_scopes: true)

      scope.variables.each do |var|
        next if var.ignored? || var.used_in_macro? || var.captured_by_block?
        next if exclude_type_declarations? && scope.assigns_type_dec?(var.name)

        var.assignments.each do |assign|
          check_assignment(source, assign, var)
        end
      end
    end

    private def check_assignment(source, assign, var)
      return if assign.referenced?

      case target_node = assign.target_node
      when Crystal::TypeDeclaration
        issue_for target_node.var, MSG % var.name
      else
        issue_for target_node, MSG % var.name
      end
    end
  end
end
