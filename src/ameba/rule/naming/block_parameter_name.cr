module Ameba::Rule::Naming
  # A rule that reports non-descriptive block parameter names.
  #
  # Favour this:
  #
  # ```
  # tokens.each { |token| token.last_accessed_at = Time.utc }
  # ```
  #
  # Over this:
  #
  # ```
  # tokens.each { |t| t.last_accessed_at = Time.utc }
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/BlockParameterName:
  #   Enabled: true
  #   MinNameLength: 3
  #   AllowNamesEndingInNumbers: true
  #   AllowedNames: [e, i, j, k, v, x, y, ex, io, ws, op, tx, id, ip, k1, k2, v1, v2, wg]
  #   ForbiddenNames: []
  # ```
  class BlockParameterName < Base
    properties do
      since_version "1.6.0"
      description "Disallows non-descriptive block parameter names"
      min_name_length 3
      allow_names_ending_in_numbers true
      allowed_names %w[e i j k v x y ex io ws op tx id ip k1 k2 v1 v2 wg]
      forbidden_names %w[]
    end

    MSG = "Disallowed block parameter name found"

    def test(source, node : Crystal::Call)
      node.try(&.block).try(&.args).try &.each do |arg|
        next if valid_name?(arg.name)

        next unless location = arg.location
        end_location =
          location.adjust(column_number: arg.name.size - 1)

        issue_for location, end_location, MSG
      end
    end

    private def valid_name?(name)
      return true if name.blank? # TODO: handle unpacked variables
      return true if name.starts_with?('_') || name.in?(allowed_names)

      return false if name.in?(forbidden_names)
      return false if name.size < min_name_length
      return false if name[-1].ascii_number? && !allow_names_ending_in_numbers?

      true
    end
  end
end
