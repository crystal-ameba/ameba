module Ameba::Rule::Lint
  # A rule that disallows redundant `each_with_object` calls.
  #
  # For example, this is considered invalid:
  #
  # ```
  # collection.each_with_object(0) do |e|
  #   # ...
  # end
  #
  # collection.each_with_object(0) do |e, _|
  #   # ...
  # end
  # ```
  #
  # and it should be written as follows:
  #
  # ```
  # collection.each do |e|
  #   # ...
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/RedundantWithObject:
  #   Enabled: true
  # ```
  class RedundantWithObject < Base
    properties do
      description "Disallows redundant `with_object` calls"
    end

    MSG = "Use `each` instead of `each_with_object`"

    def test(source, node : Crystal::Call)
      return if node.name != "each_with_object" ||
                node.args.size != 1 ||
                !(block = node.block) ||
                with_index_arg?(block)

      issue_for node, MSG, prefer_name_location: true
    end

    private def with_index_arg?(block : Crystal::Block)
      block.args.size >= 2 && block.args.last.name != "_"
    end
  end
end
