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

    HOOK_NAMES = %w[
      inherited
      included extended
      method_missing method_added
      finished
    ]

    def test(source)
      DocumentationVisitor.new self, source
    end

    def test(source, node : Crystal::ClassDef)
      ignore_classes? || check_missing_doc(source, node)
    end

    def test(source, node : Crystal::ModuleDef)
      ignore_modules? || check_missing_doc(source, node)
    end

    def test(source, node : Crystal::EnumDef)
      ignore_enums? || check_missing_doc(source, node)
    end

    def test(source, node : Crystal::Def)
      ignore_defs? || check_missing_doc(source, node)
    end

    def test(source, node : Crystal::Macro)
      return if node.name.in?(HOOK_NAMES)

      ignore_macros? || check_missing_doc(source, node)
    end

    private def check_missing_doc(source, node)
      return unless node.visibility.public?
      return if node.doc.presence

      issue_for(node, MSG)
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
