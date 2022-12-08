module Ameba::Rule::Lint
  # A rule that disallows a rescued exception that get shadowed by a
  # less specific exception being rescued before a more specific
  # exception is rescued.
  #
  # For example, this is invalid:
  #
  # ```
  # begin
  #   do_something
  # rescue Exception
  #   handle_exception
  # rescue ArgumentError
  #   handle_argument_error_exception
  # end
  # ```
  #
  # And it has to be written as follows:
  #
  # ```
  # begin
  #   do_something
  # rescue ArgumentError
  #   handle_argument_error_exception
  # rescue Exception
  #   handle_exception
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/ShadowedException:
  #   Enabled: true
  # ```
  class ShadowedException < Base
    properties do
      description "Disallows rescued exception that get shadowed"
    end

    MSG = "Shadowed exception found: %s"

    def test(source, node : Crystal::ExceptionHandler)
      rescues = node.rescues
      return if rescues.nil?

      shadowed(rescues).each do |path|
        issue_for path, MSG % path.names.join("::")
      end
    end

    private def shadowed(rescues, catch_all = false)
      traversed_types = Set(String).new

      rescues = filter_rescues(rescues)
      rescues.each_with_object([] of Crystal::Path) do |types, shadowed|
        case
        when catch_all
          shadowed.concat(types)
          next
        when types.any?(&.single?("Exception"))
          nodes = types.reject(&.single?("Exception"))
          shadowed.concat(nodes) unless nodes.empty?
          catch_all = true
          next
        else
          nodes = types.select { |path| traverse(path.to_s, traversed_types) }
          shadowed.concat(nodes) unless nodes.empty?
        end
      end
    end

    private def filter_rescues(rescues)
      rescues.compact_map(&.types.try &.select(Crystal::Path))
    end

    private def traverse(path, traversed_types)
      dup = traversed_types.includes?(path)
      dup || (traversed_types << path)
      dup
    end
  end
end
