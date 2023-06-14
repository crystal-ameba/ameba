module Ameba::Rule::Style
  # Use a guard clause instead of wrapping the code inside a conditional
  # expression
  #
  # ```
  # # bad
  # def test
  #   if something
  #     work
  #   end
  # end
  #
  # # good
  # def test
  #   return unless something
  #
  #   work
  # end
  #
  # # also good
  # def test
  #   work if something
  # end
  #
  # # bad
  # if something
  #   raise "exception"
  # else
  #   ok
  # end
  #
  # # good
  # raise "exception" if something
  # ok
  #
  # # bad
  # if something
  #   foo || raise("exception")
  # else
  #   ok
  # end
  #
  # # good
  # foo || raise("exception") if something
  # ok
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/GuardClause:
  #   Enabled: true
  # ```
  class GuardClause < Base
    include AST::Util

    properties do
      enabled false
      description "Check for conditionals that can be replaced with guard clauses"
    end

    MSG = "Use a guard clause (`%s`) instead of wrapping the " \
          "code inside a conditional expression."

    def test(source)
      AST::NodeVisitor.new self, source, skip: [
        Crystal::Assign,
      ]
    end

    def test(source, node : Crystal::Def)
      final_expression =
        if (body = node.body).is_a?(Crystal::Expressions)
          body.last
        else
          body
        end

      case final_expression
      when Crystal::If, Crystal::Unless
        check_ending_if(source, final_expression)
      end
    end

    def test(source, node : Crystal::If | Crystal::Unless)
      return if accepted_form?(source, node, ending: false)

      case
      when guard_clause = guard_clause(node.then)
        parent, conditional_keyword = node.then, keyword(node)
      when guard_clause = guard_clause(node.else)
        parent, conditional_keyword = node.else, opposite_keyword(node)
      end

      return unless guard_clause && parent && conditional_keyword

      guard_clause_source = guard_clause_source(source, guard_clause, parent)
      report_issue(source, node, guard_clause_source, conditional_keyword)
    end

    private def check_ending_if(source, node)
      return if accepted_form?(source, node, ending: true)

      report_issue(source, node, "return", opposite_keyword(node))
    end

    private def report_issue(source, node, scope_exiting_keyword, conditional_keyword)
      return unless keyword_loc = node.location
      return unless cond_code = node_source(node.cond, source.lines)

      keyword_end_loc = keyword_loc.adjust(column_number: keyword(node).size - 1)

      example = "#{scope_exiting_keyword} #{conditional_keyword} #{cond_code}"
      # TODO: check if example is too long for single line

      if node.else.is_a?(Crystal::Nop)
        return unless end_end_loc = node.end_location

        end_loc = end_end_loc.adjust(column_number: {{ 1 - "end".size }})

        issue_for keyword_loc, keyword_end_loc, MSG % example do |corrector|
          replacement = "#{scope_exiting_keyword} #{conditional_keyword}"

          corrector.replace(keyword_loc, keyword_end_loc, replacement)
          corrector.remove(end_loc, end_end_loc)
        end
      else
        issue_for keyword_loc, keyword_end_loc, MSG % example
      end
    end

    private def keyword(node : Crystal::If)
      "if"
    end

    private def keyword(node : Crystal::Unless)
      "unless"
    end

    private def opposite_keyword(node : Crystal::If)
      "unless"
    end

    private def opposite_keyword(node : Crystal::Unless)
      "if"
    end

    private def accepted_form?(source, node, ending)
      return true if node.is_a?(Crystal::If) && node.ternary?
      return true unless cond_loc = node.cond.location
      return true unless cond_end_loc = node.cond.end_location
      return true unless cond_loc.line_number == cond_end_loc.line_number
      return true unless (then_loc = node.then.location).nil? || cond_loc < then_loc

      if ending
        !node.else.is_a?(Crystal::Nop)
      else
        return true if node.else.is_a?(Crystal::Nop)
        return true unless code = node_source(node, source.lines)

        code.starts_with?("elsif")
      end
    end

    private def guard_clause(node)
      node = node.right if node.is_a?(Crystal::BinaryOp)

      return unless location = node.location
      return unless end_location = node.end_location
      return unless location.line_number == end_location.line_number

      case node
      when Crystal::Call
        node if node.obj.nil? && node.name == "raise"
      when Crystal::Return, Crystal::Break, Crystal::Next
        node
      end
    end

    def guard_clause_source(source, guard_clause, parent)
      node = parent.is_a?(Crystal::BinaryOp) ? parent : guard_clause

      node_source(node, source.lines)
    end
  end
end
