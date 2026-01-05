module Ameba::Rule::Style
  # A rule that enforces consistent naming of `Nil` in type unions.
  #
  # For example, this is considered invalid:
  #
  # ```
  # foo : String | Nil = nil
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # foo : String? = nil
  # ```
  #
  # Enable the `ExplicitNil` option to enforce the opposite behavior.
  #
  # YAML configuration example:
  #
  # ```
  # Style/VerboseNilType:
  #   Enabled: true
  #   ExplicitNil: false
  # ```
  class VerboseNilType < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Enforces consistent naming of `Nil` in type unions"
      explicit_nil false
    end

    MSG_VERBOSE = "Prefer `?` instead of `| Nil` in unions"
    MSG_SHORT   = "Prefer `| Nil` instead of `?` in unions"

    private PATTERN = /(\s*\|\s*Nil(?=\W|$))|((?<=\W|^)Nil\s*\|\s*)/

    def test(source, node : Crystal::Union)
      return unless has_nil?(node)
      return unless node_source = node_source(node, source.lines)

      # https://github.com/crystal-lang/crystal/issues/11071
      return if node_source.includes?(".class")

      if explicit_nil?
        # `String?` -> `String | Nil`
        return unless node_source.ends_with?('?')

        issue_for node, MSG_SHORT do |corrector|
          corrector.replace(node, "%s | Nil" % node_source.rstrip('?'))
        end
      else
        # `String | Nil` -> `String?`
        return unless node_source.matches?(PATTERN)

        if has_generic?(node)
          issue_for node, MSG_VERBOSE
        else
          issue_for node, MSG_VERBOSE do |corrector|
            corrector.replace(node, "%s?" % node_source
              .gsub(PATTERN, "")
              .gsub('?', "")
            )
          end
        end
      end
    end

    private def has_generic?(node : Crystal::Union)
      node.types.any? { |type| has_generic?(type) }
    end

    private def has_generic?(node)
      node.is_a?(Crystal::Generic)
    end

    private def has_nil?(node : Crystal::Union)
      node.types.any? { |type| has_nil?(type) }
    end

    private def has_nil?(node)
      path_named?(node, "Nil")
    end
  end
end
