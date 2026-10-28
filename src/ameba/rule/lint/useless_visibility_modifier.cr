module Ameba::Rule::Lint
  # A rule that disallows top level `protected` method visibility modifier,
  # since it has no effect.
  #
  # For example, this is considered invalid:
  #
  # ```
  # protected def foo
  # end
  # ```
  #
  # And has to be written as follows:
  #
  # ```
  # def foo
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UselessVisibilityModifier:
  #   Enabled: true
  # ```
  class UselessVisibilityModifier < Base
    properties do
      since_version "1.7.0"
      description "Disallows top level `protected` method visibility modifier"
    end

    MSG = "Useless visibility modifier"

    def test(source)
      AST::ScopeVisitor.new self, source, skip: [
        Crystal::ClassDef,
        Crystal::EnumDef,
        Crystal::ModuleDef,
      ]
    end

    def test(source, node : Crystal::Def, scope : AST::Scope)
      return if node.receiver || node.name == "->"
      return unless node.visibility.protected?

      return unless location = node.location

      unless begin_location = keyword_location(source, location)
        issue_for(node, MSG)
        return
      end

      end_location = begin_location.adjust(column_number: {{ "protected".size - 1 }})

      issue_for(begin_location, end_location, MSG) do |corrector|
        corrector.remove(begin_location, location.adjust(column_number: -1))
      end
    end

    # Returns the location of the `protected` keyword preceding
    # the method definition at *location*.
    private def keyword_location(source, location)
      return unless line = source.lines[location.line_number - 1]?

      code = line[0...location.column_number - 1].rstrip
      return unless code.ends_with?("protected")

      location.with(column_number: code.size - {{ "protected".size - 1 }})
    end
  end
end
