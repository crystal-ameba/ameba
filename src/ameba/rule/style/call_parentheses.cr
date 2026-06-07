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
  # ### Options
  #
  # - `ExcludeMultilineCalls` — controls whether multiline calls should be checked.
  # - `ExcludeTypeDeclarations` — controls whether calls with type declarations should be checked.
  # - `ExcludeHeredocs` — controls whether calls with heredoc arguments should be checked.
  # - `ExcludedToplevelCallNames` — contains a list of top-level method names that should not be checked.
  # - `ExcludedCallNames` — contains a list of non-top-level method names that should not be checked.
  # - `ExcludedDslCallNames` — contains a list of DSL method names that should not be checked.
  #
  #     Each entry should contain a full call chain path, with method names separated by ` > `,
  #     e.g. `properties > where`, or `builder > properties > query`.
  #
  #     Only calls with a block and no receiver are taken into account, e.g.:
  #
  #         class UserQuery
  #           builder do
  #             scope :default do
  #               where { deleted_at.nil? } # UserQuery > builder > scope > where
  #             end
  #
  #             organizations.each do |org|
  #               scope "org_#{org.name.camelcase}" do
  #                 where { id == org.id } # UserQuery > builder > scope > where
  #               end
  #             end
  #           end
  #         end
  #
  #     You can use `*` as a wildcard to match any method name and
  #     `**` to match any method name at any depth,
  #     e.g. `** > where`, or `** > where > *`.
  #
  # YAML configuration example:
  #
  # ```
  # Style/CallParentheses:
  #   Enabled: true
  #   ExcludeMultilineCalls: false
  #   ExcludeTypeDeclarations: true
  #   ExcludeHeredocs: false
  #   ExcludedToplevelCallNames: [spawn, raise, super, previous_def, exit, abort, sleep, print, printf, puts, p, p!, pp, pp!, record, class_getter, class_getter?, class_getter!, class_property, class_property?, class_property!, class_setter, getter, getter?, getter!, property, property?, property!, setter, def_equals_and_hash, def_equals, def_hash, delegate, forward_missing_to, describe, context, it, pending, fail, use_json_discriminator]
  #   ExcludedCallNames: [should, should_not]
  #   ExcludedDslCallNames: []
  # ```
  class CallParentheses < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Enforces usage of parentheses in method calls"
      enabled false
      exclude_multiline_calls false
      exclude_type_declarations true
      exclude_heredocs false
      excluded_toplevel_call_names %w[
        spawn raise super previous_def exit abort sleep
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
      excluded_dsl_call_names %w[]
    end

    MSG = "Missing parentheses in method call"

    CALL_NAMES_SEPARATOR = " > "

    def test(source)
      return if source.ecr?

      CallInBlockVisitor.new(source) do |node, visitor|
        check_for_issues(source, node, visitor)
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def check_for_issues(source, node : Crystal::Call, visitor)
      return if node.args_in_brackets? ||
                node.has_parentheses? ||
                node.expansion?

      return if setter_method?(node) ||
                operator_method?(node)

      return if visitor.type_definition != false &&
                excluded_dsl_call_names_match?(node, visitor)

      return if exclude_type_declarations? &&
                node.args.any?(Crystal::TypeDeclaration)

      heredoc_arg = find_heredoc_arg(node, source)
      return if exclude_heredocs? && heredoc_arg

      return if !node.obj && node.name.in?(excluded_toplevel_call_names)
      return if node.obj && node.name.in?(excluded_call_names)

      return unless node.block_arg ||
                    has_arguments?(node) ||
                    has_short_block?(node, source.lines)

      issue_location = {
        node.location,
        call_end_location(node, heredoc_arg, source),
      }

      location, end_location =
        replacement_locations(node, issue_location.last)

      if location && end_location
        return if exclude_multiline_calls? &&
                  !location.same_line?(end_location)

        line = source.lines[location.line_number - 1]
        rest = line[(location.column_number - 1)..-1]

        location_end = location
        location_end = location.with(column_number: line.size) if rest.strip == "\\"

        issue_for *issue_location, MSG do |corrector|
          corrector.replace(location, location_end, "(")
          corrector.insert_before(end_location, ")")
        end
      else
        issue_for *issue_location, MSG
      end
    end

    private def excluded_dsl_call_names_match?(node, visitor)
      return false if excluded_dsl_call_names.empty?

      call_chain = visitor.outer_calls
        .reject(&.obj) # 3.times { ... }
        .map(&.name)
        .push(node.name)

      case typedef = visitor.type_definition
      when Crystal::ClassDef, Crystal::ModuleDef
        call_chain.unshift(typedef.name.to_s)
      end

      call_chain = call_chain.join('~')

      dsl_call_patterns =
        excluded_dsl_call_names.map do |name|
          pattern = name
            .split(CALL_NAMES_SEPARATOR)
            .map! do |path|
              case path
              when "*"  then "([^~]+)"
              when "**" then "(.+)"
              else
                Regex.escape(path)
              end
            end
          /^#{pattern.join('~')}$/
        end

      dsl_call_patterns.any?(&.matches?(call_chain))
    end

    # Returns the replacement start and end locations for the call *node*.
    #
    #     foo.bar baz: 42 do |what, is|
    #            ^--- x  ^--- y
    #       # ...
    #     end
    #
    private def replacement_locations(node, end_location)
      location = name_end_location(node)

      location &&= location.adjust(column_number: 1)
      end_location &&= end_location.adjust(column_number: 1)

      {location, end_location}
    end

    private def call_end_location(node, heredoc_arg, source, *, ends_with_block = false)
      return node.end_location if node.has_parentheses? ||
                                  node.name.in?("[]", "[]?")

      end_location = if block = node.block
                       case
                       when short_block?(block, source.lines)
                         block.body
                       when ends_with_block
                         block
                       else
                         block.location.try(&.adjust(column_number: -2))
                       end
                     end
      end_location ||= node.block_arg
      end_location ||= heredoc_end_location(heredoc_arg, source) if heredoc_arg
      end_location ||= node.named_args.try(&.last?.try(&.value))
      end_location ||= node.args.last?

      case end_location
      when nil, node
        node.end_location
      when Crystal::Call
        # Traverse nested calls to find the end location
        call_end_location end_location,
          find_heredoc_arg(end_location, source), source,
          ends_with_block: true
      when Crystal::Location
        end_location
      when Crystal::ASTNode
        end_location.end_location
      end
    end

    private def heredoc_end_location(node, source)
      return unless location = node.location
      return unless line = source.lines[location.line_number - 1]?

      unless line.rstrip.ends_with?(',')
        location.with(column_number: line.size)
      end
    end

    private def find_heredoc_arg(node : Crystal::Call, source)
      node.named_args.try &.reverse_each.find { |arg| find_heredoc_arg(arg.value, source) } ||
        node.args.reverse_each.find { |arg| find_heredoc_arg(arg, source) }
    end

    private def find_heredoc_arg(node, source)
      node if heredoc?(node, source)
    end

    private class CallInBlockVisitor < Crystal::Visitor
      include AST::Util

      getter outer_calls = [] of Crystal::Call
      getter type_definition : Crystal::ClassDef | Crystal::ModuleDef | Bool?

      def initialize(source, &@on_call : Crystal::Call, self ->)
        source.ast.accept self
      end

      private def outer_call(value, &)
        @outer_calls.push(value)
        begin
          yield
        ensure
          @outer_calls.pop
        end
      end

      private def in_type_definition(value, &)
        prev_value = @type_definition
        begin
          @type_definition = value
          yield
        ensure
          @type_definition = prev_value
        end
      end

      def visit(node : Crystal::ClassDef | Crystal::ModuleDef)
        in_type_definition(node) do
          node.accept_children(self)
        end
        false
      end

      def visit(node : Crystal::Def)
        return true unless node.name == "->"

        in_type_definition(false) do
          node.accept_children(self)
        end
        false
      end

      def visit(node : Crystal::Call)
        @on_call.call(node, self)

        node.obj.try &.accept(self)
        node.args.each &.accept(self)
        node.named_args.try &.each &.accept(self)
        node.block_arg.try &.accept(self)
        outer_call(node) do
          node.block.try &.accept(self)
        end
        false
      end

      def visit(node : Crystal::ASTNode)
        true
      end
    end
  end
end
