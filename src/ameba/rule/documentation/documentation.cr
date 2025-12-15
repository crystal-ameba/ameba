module Ameba::Rule::Documentation
  # A rule that enforces documentation for public types:
  # modules, classes, enums, methods and macros.
  #
  # YAML configuration example:
  #
  # ```
  # Documentation/Documentation:
  #   Enabled: true
  #   IgnoreClasses: false
  #   IgnoreModules: true
  #   IgnoreEnums: false
  #   IgnoreDefs: true
  #   IgnoreMacros: false
  #   IgnoreMacroHooks: true
  #   RequireExample: false
  # ```
  class Documentation < Base
    properties do
      since_version "1.5.0"
      enabled false
      description "Enforces public types to be documented"

      ignore_classes false
      ignore_modules true
      ignore_enums false
      ignore_defs true
      ignore_macros false
      ignore_macro_hooks true
      require_example false
    end

    MSG         = "Missing documentation"
    MSG_EXAMPLE = "Missing documentation example"

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
      return if ignore_macro_hooks? && node.name.in?(MACRO_HOOK_NAMES)

      ignore_macros? || check_missing_doc(source, node, scope)
    end

    private def check_missing_doc(source, node, scope)
      # bail out if the node is not public,
      # i.e. `private def foo`
      return if !node.visibility.public?

      # bail out if the scope is not public,
      # i.e. `def bar` inside `private class Foo`
      return if (visibility = scope.visibility) && !visibility.public?

      if doc = node.doc.presence
        issue_for node, MSG_EXAMPLE unless valid_example?(doc)
      else
        issue_for node, MSG
      end
    end

    private def valid_example?(doc : String)
      !require_example? || doc.matches?(/^\s*```\n/m)
    end
  end
end
