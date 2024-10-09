module Ameba::Rule::Lint
  # A rule that reports duplicated require statements.
  #
  # ```
  # require "./thing"
  # require "./stuff"
  # require "./thing" # duplicated require
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DuplicatedRequire:
  #   Enabled: true
  # ```
  class DuplicatedRequire < Base
    properties do
      since_version "0.14.0"
      description "Reports duplicated require statements"
    end

    MSG = "Duplicated require of `%s`"

    def test(source)
      nodes = AST::TopLevelNodesVisitor.new(source.ast).require_nodes
      nodes.each_with_object([] of String) do |node, processed_require_strings|
        issue_for(node, MSG % node.string) if node.string.in?(processed_require_strings)
        processed_require_strings << node.string
      end
    end
  end
end
