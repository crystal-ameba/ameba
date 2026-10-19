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
  #   AllowedNames: [a, b, e, i, j, k, v, x, y, k1, k2, v1, v2, db, ex, id, io, ip, op, tx, wg, ws]
  #   ForbiddenNames: []
  # ```
  class BlockParameterName < Base
    include AST::Util

    properties do
      since_version "1.6.0"
      description "Disallows non-descriptive block parameter names"
      min_name_length 3
      allow_names_ending_in_numbers true
      allowed_names %w[a b e i j k v x y k1 k2 v1 v2 db ex id io ip op tx wg ws]
      forbidden_names %w[]
    end

    MSG = "Disallowed block parameter name found"

    def test(source, node : Crystal::Call)
      return unless block = node.block

      block.args.each do |arg|
        next if valid_name?(arg.name)

        issue_for(arg, MSG, prefer_name_location: true)
      end

      unpacked_block_vars(block).try &.each do |var|
        next if valid_name?(var.name)

        issue_for(var, MSG, prefer_name_location: true)
      end
    end

    private def valid_name?(name)
      return true if name.blank?
      return true if name.starts_with?('_') || name.in?(allowed_names)

      return false if name.in?(forbidden_names)
      return false if name.size < min_name_length
      return false if name[-1].ascii_number? && !allow_names_ending_in_numbers?

      true
    end
  end
end
