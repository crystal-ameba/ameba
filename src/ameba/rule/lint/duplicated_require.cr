module Ameba::Rule::Lint
  # A rule that reports duplicated `require` statements.
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
      description "Reports duplicated `require` statements"
    end

    MSG = "Duplicated require of `%s`"

    def test(source)
      nodes = AST::TopLevelNodesVisitor.new(source.ast).require_nodes
      nodes.each_with_object(Set(String).new) do |node, processed_require_strings|
        node_s = node.string
        if processed_require_strings.includes?(node_s)
          issue_for node, MSG % node_s
        else
          processed_require_strings << node_s
        end
      end
    end
  end
end
