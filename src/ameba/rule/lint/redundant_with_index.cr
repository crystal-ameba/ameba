module Ameba::Rule::Lint
  # A rule that disallows redundant `with_index` calls.
  #
  # For example, this is considered invalid:
  #
  # ```
  # collection.each.with_index do |e|
  #   # ...
  # end
  #
  # collection.each_with_index do |e, _|
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
  # Lint/RedundantWithIndex:
  #   Enabled: true
  # ```
  class RedundantWithIndex < Base
    properties do
      since_version "0.11.0"
      description "Disallows redundant `with_index` calls"
    end

    MSG_WITH_INDEX      = "Remove redundant `with_index`"
    MSG_EACH_WITH_INDEX = "Use `each` instead of `each_with_index`"

    def test(source, node : Crystal::Call)
      args, block = node.args, node.block

      return if block.nil? || args.size > 1
      return if with_index_arg?(block)

      case node.name
      when "with_index"
        report source, node, MSG_WITH_INDEX
      when "each_with_index"
        report source, node, MSG_EACH_WITH_INDEX
      end
    end

    private def with_index_arg?(block : Crystal::Block)
      block.args.size >= 2 && block.args.last.name != "_"
    end

    private def report(source, node, msg)
      issue_for node, msg, prefer_name_location: true
    end
  end
end
