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
      found_requires = Set(String).new

      nodes = AST::TopLevelNodesVisitor.new(source.ast).require_nodes
      nodes.each do |node|
        next if found_requires.add?(node.string)

        issue_for node, MSG % node.string
      end
    end
  end
end
