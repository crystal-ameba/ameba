module Ameba::Rule::Lint
  # A rule that disallows redundant `each_with_index` calls.
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

    MSG_EACH_ITERATOR = "Remove redundant `with_index`"
    MSG_EACH_BLOCK    = "Use `each` instead of `each_with_index`"

    def test(source, node : Crystal::Call)
      args, block = node.args, node.block

      return if block.nil? || args.size > 1
      return if valid_args?(block)

      case node.name
      when "with_index"
        report(source, node, MSG_EACH_ITERATOR)
      when "each_with_index"
        report(source, node, MSG_EACH_BLOCK)
      end
    end

    private def valid_args?(block : Crystal::Block)
      block.args.size >= 2 && !block.args.last.name.starts_with?('_')
    end

    private def report(source, node, msg)
      issue_for(node, msg, prefer_name_location: true)
    end
  end
end
