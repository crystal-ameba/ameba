module Ameba::Rule::Lint
  # A rule that enforces documentation for public types:
  # modules, classes, enums, methods and macros.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/Documentation:
  #   Enabled: true
  # ```
  class Documentation < Base
    properties do
      description "Enforces public types to be documented"

      ignore_classes true
      ignore_modules true
      ignore_enums false
      ignore_defs true
      ignore_macros false
    end

    MSG = "Missing documentation"

    def test(source)
      DocumentationVisitor.new self, source
    end

    def test(source, node)
      return unless node.visibility.public?

      case node
      when Crystal::ClassDef  then return if ignore_classes?
      when Crystal::ModuleDef then return if ignore_modules?
      when Crystal::EnumDef   then return if ignore_enums?
      when Crystal::Def       then return if ignore_defs?
      when Crystal::Macro     then return if ignore_macros?
      end

      issue_for(node, MSG) unless node.doc.presence
    end

    # :nodoc:
    private class DocumentationVisitor < AST::BaseVisitor
      NODES = {
        ClassDef,
        ModuleDef,
        EnumDef,
        Def,
        Macro,
      }

      @visibility : Crystal::Visibility = :public

      def visit(node : Crystal::VisibilityModifier)
        @visibility = node.modifier
        true
      end

      {% for name in NODES %}
        def visit(node : Crystal::{{ name }})
          node.visibility = @visibility
          @visibility = :public

          @rule.test @source, node
          true
        end
      {% end %}
    end
  end
end
