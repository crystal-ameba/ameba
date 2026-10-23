module Ameba::Rule::Style
  # A rule that enforces consistent naming of `Nil` in type unions.
  #
  # For example, this is considered invalid:
  #
  # ```
  # foo : String | Nil = nil
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # foo : String? = nil
  # ```
  #
  # Enable the `ExplicitNil` option to enforce the opposite behavior.
  #
  # The `OnlyTwoElementUnions` option mixes the two approaches, requiring short version (`?`)
  # in two-element unions and verbose version (`| Nil`) in multi-element unions.
  #
  # YAML configuration example:
  #
  # ```
  # Style/VerboseNilType:
  #   Enabled: true
  #   ExplicitNil: false
  #   OnlyTwoElementUnions: false
  # ```
  class VerboseNilType < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Enforces consistent naming of `Nil` in type unions"
      explicit_nil false
      only_two_element_unions false
    end

    MSG_VERBOSE = "Prefer `?` instead of `| Nil` in unions"
    MSG_SHORT   = "Prefer `| Nil` instead of `?` in unions"

    def test(source)
      UnionVisitor.new(self, source)
    end

    def test(source, node : Crystal::Union)
      types = flatten_types(node)

      return unless types.any? { |type| has_nil?(type) }
      return if types.all? { |type| has_nil?(type) }

      # Types written explicitly, i.e. without the ones implied by `T?`
      written_types = written_types(node)

      if prefer_short_nil?(types)
        # `String | Nil` -> `String?`
        return unless written_types.any? { |type| has_nil?(type) }
        return unless types.any? { |type| nilable_type?(type) }
        message = MSG_VERBOSE
      else
        # `String?` -> `String | Nil`
        return unless written_types.size < types.size
        message = MSG_SHORT
      end

      report(source, node, message)
    end

    private def report(source, node, message)
      location = union_location(node, source.lines)
      end_location = union_end_location(node, source.lines)

      # Corrected code is rendered in a single line, so we skip multi-line
      # unions (which might have comments too) to preserve their formatting
      unless location && end_location && location.same_line?(end_location) &&
             (corrected_code = type_source(node, source.lines))
        issue_for(node, message)
        return
      end

      issue_for(location, end_location, message) do |corrector|
        corrector.replace(location, end_location, corrected_code)
      end
    end

    # Returns `true` if the `?` shorthand is preferred for the union
    # consisting of (flattened) *types*.
    private def prefer_short_nil?(types)
      return false if explicit_nil?
      return true unless only_two_element_unions?

      # non-`Nil` types + `Nil` itself
      types.count { |type| !has_nil?(type) } + 1 <= 2
    end

    # Location of a union starting with a parenthesized proc notation
    # excludes the opening parenthesis, so we need to adjust it.
    private def union_location(node, code_lines)
      return unless location = node.location
      return location unless starts_with_proc?(node)
      return unless line = code_lines[location.line_number - 1]?

      prefix = line[0...location.column_number - 1].rstrip
      return unless prefix.ends_with?('(')

      location.adjust(column_number: prefix.size - location.column_number)
    end

    # Location of a union ending with a parenthesized proc notation
    # excludes the closing parenthesis, so we need to adjust it.
    private def union_end_location(node, code_lines)
      return unless end_location = node.end_location
      return end_location unless ends_with_proc?(node)
      return unless line = code_lines[end_location.line_number - 1]?

      suffix = line[end_location.column_number..]
      return unless suffix.lstrip.starts_with?(')')

      end_location.adjust(column_number: suffix.size - suffix.lstrip.size + 1)
    end

    private def starts_with_proc?(node : Crystal::Union)
      type = node.types.first
      type.location == node.location && starts_with_proc?(type)
    end

    private def starts_with_proc?(node)
      node.is_a?(Crystal::ProcNotation)
    end

    private def ends_with_proc?(node : Crystal::Union)
      type = node.types.last
      type.end_location == node.end_location && ends_with_proc?(type)
    end

    private def ends_with_proc?(node)
      node.is_a?(Crystal::ProcNotation)
    end

    private def flatten_types(node : Crystal::Union) : Array(Crystal::ASTNode)
      node.types.flat_map { |type| flatten_types(type) }
    end

    private def flatten_types(node) : Array(Crystal::ASTNode)
      [node] of Crystal::ASTNode
    end

    private def type_source(node : Crystal::Path, code_lines)
      path_name(node)
    end

    private def type_source(node : Crystal::Union, code_lines)
      union_type_sources(node, code_lines).try(&.join(" | "))
    end

    # Generic type arguments are rendered recursively, so that the nested
    # unions are corrected along with the outer one, within a single pass.
    private def type_source(node : Crystal::Generic, code_lines)
      return unless (name = node.name).is_a?(Crystal::Path)

      args = node.type_vars.map do |type|
        type_source(type, code_lines) || return
      end
      node.named_args.try &.each do |arg|
        return unless value = type_source(arg.value, code_lines)
        args << "#{::Symbol.quote_for_named_argument(arg.name)}: #{value}"
      end

      case node.suffix
      in .question?
        nil
      in .asterisk?
        type_operand(node.type_vars.first, code_lines).try { |type| "#{type}*" }
      in .bracket?
        type_operand(node.type_vars.first, code_lines).try { |type| "#{type}[#{args.last}]" }
      in .none?
        # `{String, Int32}` and `{foo: String}` shorthands have no location
        if name.location
          "#{type_source(name, code_lines)}(#{args.join(", ")})"
        else
          "{#{args.join(", ")}}"
        end
      end
    end

    private def type_source(node : Crystal::ProcNotation, code_lines)
      inputs = node.inputs.try &.map do |type|
        type_source(type, code_lines) || return
      end
      output = node.output.try do |type|
        type_operand(type, code_lines) || return
      end

      [inputs.try(&.join(", ")), "->", output].compact.join(' ')
    end

    # Some nodes (i.e. `NumberLiteral`) lack the end location
    private def type_source(node, code_lines)
      node_source(node, code_lines) || node.to_s
    end

    # Same as `#type_source`, but wraps multi-type unions and procs
    # in parentheses, to be used as an operand of the type expression.
    private def type_operand(node : Crystal::Union, code_lines)
      return unless sources = union_type_sources(node, code_lines)

      sources.size > 1 ? "(#{sources.join(" | ")})" : sources.first
    end

    private def type_operand(node : Crystal::ProcNotation, code_lines)
      type_source(node, code_lines).try { |code| "(#{code})" }
    end

    private def type_operand(node, code_lines)
      type_source(node, code_lines)
    end

    # Returns sources of the flattened union types, with `Nil` type moved
    # to the end, either as a `?` suffix or as a separate `Nil` type.
    #
    # Since unions are flattened, removing `Nil` type from anywhere in the
    # union and appending `?` (or `| Nil`) is semantically the same and does
    # not affect the type of the union.
    private def union_type_sources(node : Crystal::Union, code_lines)
      types = flatten_types(node)
      nilable = types.any? { |type| has_nil?(type) }

      types.reject! { |type| has_nil?(type) }
      return %w[Nil] if types.empty?

      sources = types.map do |type|
        type_operand(type, code_lines) || return
      end
      return sources unless nilable

      if prefer_short_nil?(types) &&
         (index = types.rindex { |type| nilable_type?(type) })
        sources[index] += '?'
      else
        sources << "Nil"
      end
      sources
    end

    # Returns `true` if the *node* can be suffixed with `?`, which
    # is not the case for the metaclasses (i.e. `Foo.class?`).
    #
    # https://github.com/crystal-lang/crystal/issues/11071
    private def nilable_type?(node)
      !node.is_a?(Crystal::Metaclass) && !has_nil?(node)
    end

    # Same as `#flatten_types`, but skips the `Nil` types implied by `T?`
    private def written_types(node : Crystal::Union) : Array(Crystal::ASTNode)
      types = short_nil?(node) ? node.types[...-1] : node.types
      types.flat_map { |type| written_types(type) }
    end

    private def written_types(node) : Array(Crystal::ASTNode)
      [node] of Crystal::ASTNode
    end

    # Returns `true` if the *node* is a `T?` shorthand, which the parser
    # expands to `T | ::Nil`, with `::Nil` sharing the location of `T`.
    private def short_nil?(node : Crystal::Union)
      return false unless node.types.size == 2

      type, nil_type = node.types
      nil_type.is_a?(Crystal::Path) && nil_type.global? && has_nil?(nil_type) &&
        nil_type.location == type.location &&
        nil_type.end_location == type.end_location
    end

    private def has_nil?(node)
      path_named?(node, "Nil")
    end

    private class UnionVisitor < AST::NodeVisitor
      # Nested unions are flattened by the compiler, so we inspect
      # them only as a part of the outermost union.
      def visit(node : Crystal::Union)
        return false if skip?(node)

        @rule.test(@source, node)
        accept_types(node)
        false
      end

      private def accept_types(node : Crystal::Union)
        node.types.each { |type| accept_types(type) }
      end

      private def accept_types(node)
        node.accept(self)
      end
    end
  end
end
