module Ameba::Rule::Style
  # A rule that enforces usage of parentheses in method or macro calls.
  #
  # For example, this (and all of its variants) is considered invalid:
  #
  # ```
  # user.update name: "John", age: 30
  # ```
  #
  # And should be replaced by the following:
  #
  # ```
  # user.update(name: "John", age: 30)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/CallParentheses:
  #   Enabled: true
  #   ExcludeTypeDeclarations: true
  #   ExcludeHeredocs: false
  #   ExcludedToplevelCallNames: [raise, super, previous_def, exit, abort, sleep, print, printf, puts, p, p!, pp, pp!, record, class_getter, class_getter?, class_getter!, class_property, class_property?, class_property!, class_setter, getter, getter?, getter!, property, property?, property!, setter, def_equals_and_hash, def_equals, def_hash, delegate, forward_missing_to, describe, context, it, pending, fail, use_json_discriminator]
  #   ExcludedCallNames: [should, should_not]
  # ```
  class CallParentheses < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Enforces usage of parentheses in method calls"
      enabled false
      exclude_type_declarations true
      exclude_heredocs false
      excluded_toplevel_call_names %w[
        raise super previous_def exit abort sleep
        print printf puts p p! pp pp! record
        class_getter class_getter? class_getter!
        class_property class_property? class_property!
        class_setter getter getter? getter!
        property property? property! setter
        def_equals_and_hash def_equals def_hash
        delegate forward_missing_to
        describe context it pending fail
        use_json_discriminator
      ]
      excluded_call_names %w[should should_not]
    end

    MSG = "Missing parentheses in method call"

    # ameba:disable Metrics/CyclomaticComplexity
    def test(source, node : Crystal::Call)
      return if node.args_in_brackets? ||
                node.has_parentheses? ||
                node.expansion? ||
                node.name.ends_with?('=') ||
                operator_method?(node)

      return unless node.args.present? ||
                    node.named_args.try(&.present?)

      return if exclude_type_declarations? &&
                node.args.any?(Crystal::TypeDeclaration)

      heredoc_arg = find_heredoc_arg(node, source)
      return if exclude_heredocs? && heredoc_arg

      return if !node.obj && node.name.in?(excluded_toplevel_call_names)
      return if node.obj && node.name.in?(excluded_call_names)

      location, end_location =
        replacement_locations(node, heredoc_arg, source)

      if location && end_location
        issue_for node, MSG do |corrector|
          corrector.replace(location, location, "(")
          corrector.insert_before(end_location, ")")
        end
      else
        issue_for node, MSG
      end
    end

    # Returns the replacement start and end locations for the call *node*.
    #
    #     foo.bar baz: 42 do |what, is|
    #            ^--- x  ^--- y
    #       # ...
    #     end
    #
    private def replacement_locations(node, heredoc_arg, source)
      location = name_end_location(node).try(&.adjust(column_number: 1))
      source_lines = source.lines

      case
      when block = node.block
        end_location = if short_block?(block, source_lines)
                         block.body.end_location
                       else
                         block.location.try(&.adjust(column_number: -2))
                       end
      when heredoc_arg
        if arg_location = heredoc_arg.location
          if line = source_lines[arg_location.line_number - 1]?
            end_location = arg_location.with(column_number: line.size)
          end
        end
      else
        if end_location = node.end_location
          # handle edge-cases in which the end location is not valid
          end_location = nil unless end_location.line_number.positive? &&
                                    end_location.column_number.positive?
        end
      end

      if end_location
        end_location = end_location.adjust(column_number: 1)
      end

      {location, end_location}
    end

    private def find_heredoc_arg(node : Crystal::Call, source)
      node.args.find { |arg| find_heredoc_arg(arg, source) }
    end

    private def find_heredoc_arg(node, source)
      node if heredoc?(node, source)
    end
  end
end
