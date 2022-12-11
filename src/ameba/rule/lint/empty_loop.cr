module Ameba::Rule::Lint
  # A rule that disallows empty loops.
  #
  # This is considered invalid:
  #
  # ```
  # while false
  # end
  #
  # until 10
  # end
  #
  # loop do
  #   # nothing here
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # a = 1
  # while a < 10
  #   a += 1
  # end
  #
  # until socket_opened?
  # end
  #
  # loop do
  #   do_something_here
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/EmptyLoop:
  #   Enabled: true
  # ```
  class EmptyLoop < Base
    include AST::Util

    properties do
      description "Disallows empty loops"
    end

    MSG = "Empty loop detected"

    def test(source, node : Crystal::Call)
      check_node(source, node, node.block) if loop?(node)
    end

    def test(source, node : Crystal::While | Crystal::Until)
      check_node(source, node, node.body) if literal?(node.cond)
    end

    private def check_node(source, node, loop_body)
      body = loop_body.is_a?(Crystal::Block) ? loop_body.body : loop_body
      return unless body.nil? || body.nop?

      issue_for node, MSG
    end
  end
end
