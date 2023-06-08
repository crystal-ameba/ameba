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
      enabled false
      description "Enforces public types to be documented"

      ignore_classes false
      ignore_modules true
      ignore_enums false
      ignore_defs true
      ignore_macros false
    end

    MSG = "Missing documentation"

    MACRO_HOOK_NAMES = %w[
      inherited
      included extended
      method_missing method_added
      finished
    ]

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::ClassDef, scope : AST::Scope)
      ignore_classes? || check_missing_doc(source, node, scope)
    end

    def test(source, node : Crystal::ModuleDef, scope : AST::Scope)
      ignore_modules? || check_missing_doc(source, node, scope)
    end

    def test(source, node : Crystal::EnumDef, scope : AST::Scope)
      ignore_enums? || check_missing_doc(source, node, scope)
    end

    def test(source, node : Crystal::Def, scope : AST::Scope)
      ignore_defs? || check_missing_doc(source, node, scope)
    end

    def test(source, node : Crystal::Macro, scope : AST::Scope)
      node.name.in?(MACRO_HOOK_NAMES) ||
        ignore_macros? || check_missing_doc(source, node, scope)
    end

    private def check_missing_doc(source, node, scope)
      visibility = scope.visibility

      return if visibility && !visibility.public?
      return if node.doc.presence

      issue_for(node, MSG)
    end
  end
end
