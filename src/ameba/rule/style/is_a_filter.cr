module Ameba::Rule::Style
  # This rule is used to identify usage of `is_a?/nil?` calls within filters.
  #
  # For example, this is considered invalid:
  #
  # ```
  # matches = %w[Alice Bob].map(&.match(/^A./))
  #
  # matches.any?(&.is_a?(Regex::MatchData)) # => true
  # matches.one?(&.nil?)                    # => true
  #
  # typeof(matches.reject(&.nil?))                    # => Array(Regex::MatchData | Nil)
  # typeof(matches.select(&.is_a?(Regex::MatchData))) # => Array(Regex::MatchData | Nil)
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # matches = %w[Alice Bob].map(&.match(/^A./))
  #
  # matches.any?(Regex::MatchData) # => true
  # matches.one?(Nil)              # => true
  #
  # typeof(matches.reject(Nil))              # => Array(Regex::MatchData)
  # typeof(matches.select(Regex::MatchData)) # => Array(Regex::MatchData)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/IsAFilter:
  #   Enabled: true
  #   FilterNames:
  #     - select
  #     - reject
  #     - any?
  #     - all?
  #     - none?
  #     - one?
  # ```
  class IsAFilter < Base
    properties do
      description "Identifies usage of `is_a?/nil?` calls within filters."
      filter_names : Array(String) = %w(select reject any? all? none? one?)
    end

    MSG = "Use `%s(%s)` instead of `%s {...}`"

    def test(source, node : Crystal::Call)
      return unless node.name.in?(filter_names)
      return unless (block = node.block)
      return unless (body = block.body).is_a?(Crystal::IsA)
      return unless (path = body.const).is_a?(Crystal::Path)
      return unless body.obj.is_a?(Crystal::Var)

      name = path.names.join("::")
      name = "::#{name}" if path.global? && !body.nil_check?

      end_location = node.end_location
      if !end_location || end_location.try(&.column_number.zero?)
        if end_location = path.end_location
          end_location = Crystal::Location.new(
            end_location.filename,
            end_location.line_number,
            end_location.column_number + 1
          )
        end
      end

      issue_for node.name_location, end_location,
        MSG % {node.name, name, node.name}
    end
  end
end
